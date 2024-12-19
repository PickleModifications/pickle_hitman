import { Button, Flex, Group, ScrollArea, useMantineTheme } from "@mantine/core";
import { TableScrollArea } from "../tablescrollarea/TableScrollArea";
import { useLocale } from "../../providers/locale/Locale";
import { Currency } from "../../providers/currency/Currency";
import { useState } from "react";
import { useHitmanApp } from "../../providers/hitman/Hitman";
import { useNuiEvent } from "../../providers/nui/useNui";
import { IconPlus } from "@tabler/icons-react";
import { MenuModal } from "../menumodal/MenuModal";
import { fetchNui } from "../../providers/nui/fetchNui";
import { Search } from "../search/Search";
import { useConfig } from "../../providers/config/Config";
import { Datetime } from "../datetime/Datetime";

export type Hit = {
    id: string;
    issuer?: string;
    image?: string;
    description?: string;
    source?: number;
    hitmanId?: number;
    date: number;
    name: string;
    reward: number;
}

export type Player = {
    source?: number;
    identifier: string;
    name: string;
    image?: string;
    reward?: number;
    description?: string;
}

export default function HitsPage() {
    const theme = useMantineTheme();
    const translate = useLocale();
    const {config} = useConfig();
    const {hitmanApp, setHitmanApp} = useHitmanApp();
    const [hits, setHits] = useState<Hit[]>(hitmanApp.hits);
    const [selectedPlayer, setSelectedPlayer] = useState<Player | null>(null);
    const [players, setPlayers] = useState<Player[]>([]);
    const [search, setSearch] = useState("");
    const [addingPlayer, setAddingPlayer] = useState(false);
    const [viewHit, setViewHit] = useState<Hit | null>(null);
    const [viewingHit, setViewingHit] = useState(false);
    const inputStyle = {
        background: theme.colors.dark[5], 
        color: "white", 
        border: "none", 
        padding: "2px 2px"
    }
    let filteredPlayers = []
    let playersFiltered = 0;
    let morePlayers = false;
    for (let i = 0; i < players.length; i++) {
        let player = players[i];
        if (player.name.toLowerCase().includes(search) || player.source?.toString().includes(search)) {
            if (playersFiltered >= 10) {
                morePlayers = true;
                break;
            }
            filteredPlayers.push(player);
            playersFiltered++;
        }
    }
    let filteredHits = hits.filter((hit) => {
        if (!hit.id.startsWith("npc:") && (hit.source == null || hit.source < 1)) {
            return false;
        }
        return (hit.hitmanId == null || hit.hitmanId < 1);
    });

    useNuiEvent("updateHits", function(data) {
        setHits(data.hits);
    });

    const canRemoveHit = function(hit: Hit) {
        if (config.permissions.cancelHits) return true;
        if (hit.issuer && hit.issuer == config.identifier) return true;
        return false;
    }
    return (
        <Flex p={10} flex={1} w={"100%"} h={"100%"} pos={"relative"} style={{borderBottomLeftRadius: 5, borderBottomRightRadius: 5, backgroundColor: "transparent"}}>
            <TableScrollArea defaultSort={{column: 2, descending: false}} data={{
                caption: translate("header_hit"),
                head: ["", translate("available_hits_name"), translate("available_hits_date"),  translate("available_hits_reward"), ''],
                body: filteredHits.map((hit, hitIndex) => [
                    <img src={hit.image || config.defaultPlayerImage} alt={hit.name} width={6 * 6} height={8 * 6}/>,
                    hit.name, 
                    Datetime(hit.date, config.currency.locale),
                    Currency(hit.reward, config),
                    <Button size="xs" color={"dark.7"} onClick={() => {
                        setViewHit(hit)
                        setViewingHit(true)
                    }}>{translate("available_hits_view")}</Button>
                ])
            }} options={config.permissions.placeHits && (<Button color={"dark.5"} onClick={() => {
                fetchNui<{ players: Player[] }>("getPlayers", {}).then((data) => {
                    setAddingPlayer(true)
                    setPlayers(data.players);
                });
            }}><IconPlus style={{marginRight: 10}}/>{translate("select_player_add_hit")}</Button>)}/>
            <MenuModal title={translate("add_new_hit")} close={() => {
                setAddingPlayer(false);
                setTimeout(() => {
                    setSelectedPlayer(null);
                }, 200);
            }} visible={addingPlayer}>
                {selectedPlayer ? (
                    <Flex gap={10} pl={10} pr={10} direction={"column"}>
                        <Group gap={5} w={"100%"} p={10} bg={"dark.5"}>
                            <Flex>{selectedPlayer.name}</Flex>
                            <Flex>{translate("player_source", selectedPlayer.source)}</Flex>
                        </Group>
                        <Flex gap={5} direction={"column"}>
                            <label>{translate("hit_image_url")}</label>
                            <input style={inputStyle} type="text" onChange={(e) => {
                                setSelectedPlayer({
                                    ...selectedPlayer,
                                    image: e.target.value
                                });
                            }} />
                        </Flex>
                        <Flex gap={5} direction={"column"}>
                            <label>{translate("hit_reward_amount")}</label>
                            <input style={inputStyle} type="text" onChange={(e) => {
                                setSelectedPlayer({
                                    ...selectedPlayer,
                                    reward: parseInt(e.target.value) || 0
                                });
                            }} />
                        </Flex>
                        <Flex gap={5} direction={"column"}>
                            <label>{translate("hit_description")}</label>
                            <input style={inputStyle} type="text" onChange={(e) => {
                                setSelectedPlayer({
                                    ...selectedPlayer,
                                    description: e.target.value
                                });
                            }} />
                        </Flex>
                        <Flex gap={5} direction={"column"}>
                            <Button color={"green"} onClick={() => {
                                fetchNui("addPlayerToHit", { player: selectedPlayer }).then(() => {
                                    setAddingPlayer(false);
                                    setTimeout(() => {
                                        setSelectedPlayer(null);
                                    }, 200);
                                });
                            }}>{translate("select_player_add_hit")}</Button>
                            <Button color={"dark.5"} onClick={() => {
                                setSelectedPlayer(null);
                            }}>{translate("select_player_back")}</Button>
                        </Flex>
                    </Flex>
                ) : (
                    <Flex gap={20} pl={10} pr={10} direction={"column"}>
                        <Flex gap={5} direction={"column"}>
                            <div style={{color: theme.colors.dark[3]}}>Showing {filteredPlayers.length} / {players.length} player(s)</div>
                            <Search size='xs' onChange={(event) => {
                                setSearch(event.currentTarget.value.toLowerCase());
                            }}/>
                        </Flex>
                        <ScrollArea h={220}>
                            <Flex gap={5} direction={"column"}> 
                                {filteredPlayers.length < 1 ? "No players to select." : filteredPlayers.map((player, playerIndex) => {
                                    return (
                                        <Group onClick={() => setSelectedPlayer(player)} style={{cursor: "pointer", userSelect: "none"}} gap={5} w={"100%"} p={10} key={playerIndex} bg={"dark.6"}>
                                            <Flex>{player.name}</Flex>
                                            <Flex>{translate("player_source", player.source)}</Flex>
                                        </Group>    
                                    )
                                })}     
                            </Flex>
                        </ScrollArea>
                    </Flex>
                )}
            </MenuModal>
            <MenuModal title={translate("view_hit")} close={() => {
                setViewingHit(false);
                setTimeout(() => {
                    setViewHit(null);
                }, 200);
            }} visible={viewingHit}>
                {viewHit && (
                    <Flex gap={10} pl={10} pr={10} direction={"column"}>
                        <Flex align={"center"} gap={10}>
                            <img width={6 * 12} height={8 * 12} src={viewHit.image || config.defaultPlayerImage}></img>
                            <Flex direction={"column"}>
                                <Flex gap={10}>
                                    <b>{translate("available_hits_name")}:</b>
                                    {viewHit.name}
                                </Flex>
                                <Flex gap={10}>
                                    <b>{translate("available_hits_date")}:</b>
                                    {Datetime(viewHit.date, config.currency.locale)}
                                </Flex>
                                <Flex gap={10}>
                                    <b>{translate("available_hits_reward")}:</b>
                                    {Currency(viewHit.reward, config)}
                                </Flex>
                            </Flex>
                        </Flex>
                        <ScrollArea style={{ height: 100, color: theme.colors.dark[1]}}>
                            {viewHit.description || "No description available."}
                        </ScrollArea>
                        {(<Button color={"green"} onClick={() => {
                            fetchNui("acceptHit", { hit: viewHit }).then(() => {
                                setViewingHit(false);
                            });
                        }}>{translate("available_hits_accept")}</Button>)}
                        {canRemoveHit(viewHit) && (<Button color={"red"} onClick={() => {
                            fetchNui("declineHit", { hit: viewHit }).then(() => {
                                setViewingHit(false);
                            });
                        }
                        }>{translate("available_hits_remove")}</Button>)}
                    </Flex>
                )}
            </MenuModal>
        </Flex>
    )
}