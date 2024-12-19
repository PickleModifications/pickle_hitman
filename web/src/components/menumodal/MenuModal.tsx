import { Overlay, Group, useMantineTheme, Container, Text, CloseIcon, ScrollArea, Divider} from "@mantine/core";
import { IconX } from "@tabler/icons-react";
import classes from "./MenuModal.module.css";

export function MenuModal({visible, title, close, children} : {visible: boolean, title?: string, close?: () => void, children?: any}) {
    const theme = useMantineTheme();
    return (
        <Overlay className={visible ? classes.overlay : classes.overlayHidden} style={{display: "flex", justifyContent: "center", alignItems: "center", overflow: "hidden"}}>
            <Container w={"50%"} mah={"calc(100% - 80px)"} p={0} pb={18} m={40} style={{zIndex: 201, borderRadius: 5, backgroundColor: theme.colors.dark[7]}}>
                <Group pl={20} pt={10} pb={12} pr={10} justify="space-between">
                    {title ? <Text size="xl" fw={700} maw={600} style={{textOverflow: 'ellipsis', overflow: 'hidden', textWrap:"nowrap"}}>{title}</Text> : <Text size="xl"></Text>}
                    <IconX cursor={"pointer"} onClick={close} size={20} color={theme.colors.dark[0]} />
                </Group>
                <Container pl={5} pr={5} m={0} style={{flexGrow: 1, overflowY: "auto"}}>
                    <ScrollArea h={"100%"}>
                        {children}
                    </ScrollArea>
                </Container>
            </Container>
            <Container onClick={close} w={"100%"} h={"100%"} p={0} m={0} style={{position:"absolute", top: 0, left: 0, borderRadius: 5}}>
            </Container>
        </Overlay>
    )
}