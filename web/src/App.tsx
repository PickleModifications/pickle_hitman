import { ReactNode, createContext, useContext, useState } from 'react'
import '@mantine/core/styles.css';
import { Button, CloseButton, Flex, MantineProvider, Text, useMantineTheme } from '@mantine/core'
import { ConfigProvider, useConfig } from './providers/config/Config';
import { useLocale } from './providers/locale/Locale';
import { HitmanAppProvider, useHitmanApp } from './providers/hitman/Hitman';
import HitsPage from './components/hitspage/HitsPage';
import { useNuiEvent } from './providers/nui/useNui';
import { fetchNui } from './providers/nui/fetchNui';
import BackgroundImageFile from './assets/background.png';
import { useEffect, useRef } from 'react';
import { Currency } from './providers/currency/Currency';
import { CSSProperties } from 'react';

type AppSection = {
  name: string;
  label: string;
}

export type CurrentHit = {
  id: number;
  image?: string;
  description?: string;
  objective?: string;
  date: number;
  name: string;
  reward: number;
}

export type Position = {
  x: number;
  y: number;
}

export type CameraState = "idle" | "scanning" | "match" | "no_match"

export function KeyboardIcon({text, style} : {text: string, style?: CSSProperties}) {
  return (
    <Flex align={'center'} style={{background: "white", color:"black", fontWeight: 700, fontSize: "12px", borderRadius: 2, padding: "0px 10px", height: "18px", margin: "0px 5px", ...style}}>{text}</Flex>
  );
}

function HitContent({section} : {section: string}) {
  const theme = useMantineTheme()
  if (section == "hits") {
    return <HitsPage/>
  }
  return (
    <Flex flex={1} w={"100%"} h={"100%"} style={{borderBottomLeftRadius: 5, borderBottomRightRadius: 5, backgroundColor: theme.colors.dark[8]}}>
      ERROR. NO CONTENT.
    </Flex>
  );
}

function HitApp() {
  const [show, setShow] = useState(false)
  const [showDisplay, setShowDisplay] = useState(false)
  const theme = useMantineTheme()
  const [sections, setSections] = useState<AppSection[]>([]);
  const setAppDisplay = function(bool: boolean) {
    if (bool) {
      setShowDisplay(true)
      setTimeout(() => {
        setShow(true)
      }, 10)
    }
    else {
      setShow(false)
      setTimeout(() => {
        setShowDisplay(false)
      }, 200)
    }
  }
  const [selectedSection, setSelectedSection] = useState((sections.length > 0) ? sections[0].name : null)
  useNuiEvent("setAppDisplay", function(data) {
    setAppDisplay(data.data)
  })
  useNuiEvent("setSections", function(data) {
    let newSections = data.sections;
    let sectionIndex = -1;
    if (selectedSection != null) {
      for (let i = 0; i < newSections.length; i++) {
        if (newSections[i].name == selectedSection) {
          sectionIndex = i;
          break;
        }
      }
    }
    if (sectionIndex > 0) {
      if (selectedSection != newSections[sectionIndex].name) {
        setSelectedSection(newSections[sectionIndex].name)
      }
    }
    else {
      setSelectedSection((newSections.length > 0) ? newSections[0].name : null)
    }
    setSections(newSections)
  })
  if (sections.length < 1) {
    if (showDisplay) {
      fetchNui("closeApp", {noAccess: true})
    }
  }
  return (
    <div style={{position: "absolute", top: "50%", left: "50%", transform: "translate(-50%, -50%)", transition: "opacity 0.2s", opacity: (show ? 1.0 : 0.0), display: (showDisplay ? "flex" : "none") }}>
      {(showDisplay && selectedSection) &&
        <Flex w={900} h={550} pos={"relative"} direction={"column"} style={{backgroundImage: 'url('+BackgroundImageFile+')', backgroundSize: "100%", borderRadius: 5}}>
          <Flex align={"center"}  w={"100%"} style={{borderTopLeftRadius: 5, borderTopRightRadius: 5}}>
            <Flex flex={1} align={"center"} justify={"center"} gap={10} p={10}>
              {sections.map((section, index) => {
                return (
                  <Flex justify={"center"} flex={1} key={index} onClick={() => {
                    if (section.name != selectedSection) {
                      setSelectedSection(section.name)
                    }
                  }} style={{cursor: "pointer", userSelect:"none", transition: "background-color 0.2s", borderRadius: 5, padding: 5, paddingLeft: 10, paddingRight: 10, backgroundColor: (selectedSection == section.name ? "rgba(255, 255, 255, 0.1)" : undefined)}}>
                    {section.label}
                  </Flex>
                )
              })}
            </Flex>
            <CloseButton mr={10} size={30} onClick={() => {
              fetchNui("closeApp", {})
            }}/>
          </Flex>
          <div style={{position: "relative", height: 495}}>
            <HitContent section={selectedSection}/>
          </div>
        </Flex>
      }
    </div>
  )
}

function OverlayApp() {
  const {config} = useConfig();
  const [show, setShow] = useState(false)
  const [interacting, setInteracting] = useState(false)
  const [currentHit, setCurrentHit] = useState<CurrentHit | null>(null)
  const [position, setPosition] = useState<Position>(config.position || {x: 10, y: 10})
  useEffect(() => { setPosition(config.position) }, [config.position])
  const theme = useMantineTheme()
  const translate = useLocale()
  useNuiEvent("setCurrentHit", function(data) {
    if (data.currentHit) {
      setCurrentHit(data.currentHit)
      setTimeout(() => {
        setShow(true)
      }, 10)
    }
    else {
      setShow(false)
      setTimeout(() => {
        setCurrentHit(null)
      }, 200)
    }
  })
  useNuiEvent("setInteracting", function(data) {
    setInteracting(data.data)
  })

  const overlayRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const overlay = overlayRef.current;
    if (!overlay) return;

    let offsetX = 0;
    let offsetY = 0;
    let isDragging = false;

    const onMouseDown = (e: MouseEvent) => {
      isDragging = true;
      offsetX = e.clientX - overlay.getBoundingClientRect().left;
      offsetY = e.clientY - overlay.getBoundingClientRect().top;
      document.addEventListener('mousemove', onMouseMove);
      document.addEventListener('mouseup', onMouseUp);
    };

    const onMouseMove = (e: MouseEvent) => {
      if (!isDragging) return;

      let newLeft = e.clientX - offsetX;
      let newTop = e.clientY - offsetY;
      const distance = 10;
      const rightBound = window.innerWidth - (overlay.offsetWidth + distance);
      const bottomBound = window.innerHeight - (overlay.offsetHeight + distance);

      if (newLeft < distance) newLeft = distance;
      if (newTop < distance) newTop = distance;
      if (newLeft > rightBound) newLeft = rightBound;
      if (newTop > bottomBound) newTop = bottomBound;

      overlay.style.left = `${newLeft}px`;
      overlay.style.top = `${newTop}px`;
    };

    const onMouseUp = () => {
      isDragging = false;
      setPosition({ x: overlay.offsetLeft, y: overlay.offsetTop });
      fetchNui("updatePosition", {x: overlay.offsetLeft, y: overlay.offsetTop})
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
    };

    overlay.addEventListener('mousedown', onMouseDown);

    return () => {
      overlay.removeEventListener('mousedown', onMouseDown);
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
    };
  }, []);

  return (
    <div ref={overlayRef} style={{ userSelect: "none", position: "absolute", width: "400px", zIndex: "1000", top: position.y + "px", left: position.x + "px", transition: "opacity 0.2s", opacity: (show ? 1.0 : 0.0), display: (currentHit ? "flex" : "none"), cursor: "move" }}>
      {(currentHit) &&
        <Flex w={"100%"} h={"100%"} p={8} gap={8} direction={"column"} style={{ borderRadius: 5, backgroundColor: "rgba(0, 0, 0, 0.75)" }} >
          <Flex gap={8} align={"center"}>
            <svg fill="white" height="20px" width="20px" version="1.1" id="Capa_1" viewBox="0 0 512 512">
              <g>
                <path d="M504,248h-16.151c-1.985-58.969-25.873-114.121-67.8-156.049S322.969,26.136,264,24.151V8c0-4.418-3.582-8-8-8   s-8,3.582-8,8v16.151c-58.969,1.985-114.121,25.872-156.049,67.8S26.136,189.031,24.151,248H8c-4.418,0-8,3.582-8,8s3.582,8,8,8   h16.151c1.985,58.969,25.873,114.121,67.8,156.049s97.079,65.815,156.049,67.8V504c0,4.418,3.582,8,8,8s8-3.582,8-8v-16.151   c58.969-1.985,114.121-25.872,156.049-67.8s65.815-97.08,67.8-156.049H504c4.418,0,8-3.582,8-8S508.418,248,504,248z    M103.265,103.265C142.17,64.36,193.306,42.139,248,40.161v16.013C144.071,60.284,60.284,144.071,56.174,248H40.161   C42.139,193.306,64.36,142.17,103.265,103.265z M103.265,408.735C64.36,369.83,42.139,318.694,40.161,264h16.008   c1.83,45.892,19.354,89.758,49.828,124.288c1.581,1.791,3.786,2.706,6.001,2.706c1.881,0,3.77-0.659,5.291-2.002   c3.313-2.924,3.628-7.979,0.705-11.292C90.101,346.097,73.997,305.989,72.177,264H112c4.418,0,8-3.582,8-8s-3.582-8-8-8H72.184   C76.275,152.894,152.894,76.275,248,72.184V112c0,4.418,3.582,8,8,8s8-3.582,8-8V72.179c32.671,1.405,64.207,11.396,91.661,29.12   c3.712,2.396,8.664,1.331,11.061-2.382c2.396-3.712,1.33-8.663-2.382-11.06C334.293,68.459,299.758,57.578,264,56.164V40.161   c54.694,1.979,105.83,24.199,144.735,63.104C447.64,142.17,469.861,193.306,471.839,248h-16.003   c-1.415-35.76-12.297-70.298-31.698-100.346c-2.397-3.712-7.349-4.776-11.06-2.381c-3.712,2.396-4.778,7.349-2.381,11.061   c17.727,27.455,27.719,58.993,29.124,91.666H400c-4.418,0-8,3.582-8,8s3.582,8,8,8h39.816   c-4.09,95.106-80.709,171.726-175.816,175.815V400c0-4.418-3.582-8-8-8s-8,3.582-8,8v39.832   c-39.292-1.648-76.125-15.447-106.966-40.161c-3.447-2.762-8.482-2.208-11.246,1.24c-2.763,3.448-2.207,8.483,1.241,11.246   c33.203,26.606,74.465,41.958,116.971,43.677v16.005C193.306,469.861,142.17,447.64,103.265,408.735z M408.735,408.735   C369.83,447.64,318.694,469.861,264,471.839v-16.013C367.93,451.716,451.716,367.929,455.826,264h16.013   C469.861,318.694,447.64,369.83,408.735,408.735z"/>
                <path d="M378.677,118.861c5.384,4.819,10.538,10.01,15.321,15.428c1.581,1.791,3.786,2.706,6,2.706c1.881,0,3.77-0.659,5.291-2.002   c3.313-2.924,3.627-7.979,0.704-11.292c-5.195-5.886-10.795-11.525-16.644-16.762c-3.292-2.945-8.35-2.667-11.296,0.625   C375.105,110.856,375.385,115.914,378.677,118.861z"/>
                <path d="M160,264h24.455c3.702,33.32,30.225,59.843,63.545,63.545V352c0,4.418,3.582,8,8,8s8-3.582,8-8v-24.455   c33.32-3.702,59.843-30.225,63.545-63.545H352c4.418,0,8-3.582,8-8s-3.582-8-8-8h-24.455c-3.702-33.32-30.225-59.843-63.545-63.545   V160c0-4.418-3.582-8-8-8s-8,3.582-8,8v24.455c-33.32,3.702-59.843,30.225-63.545,63.545H160c-4.418,0-8,3.582-8,8   S155.582,264,160,264z M200.581,264H248v47.419C223.513,307.9,204.1,288.487,200.581,264z M264,311.419V264h47.419   C307.9,288.487,288.487,307.9,264,311.419z M311.419,248H264v-47.419C288.487,204.1,307.9,223.513,311.419,248z M248,200.581V248   h-47.419C204.1,223.513,223.513,204.1,248,200.581z"/>
              </g>
            </svg>
            <Text size="15px" fw={600} c={"white"}>{translate("current_hit")}</Text>
          </Flex>
          <Flex gap={8} direction={"row"} align={"center"}>
            <img style={{pointerEvents: "none"}} width={6 * 12} height={8 * 12} src={currentHit.image}></img>
            <Flex gap={8} direction={"column"}>
              <Flex gap={8}>
                <Text size="15px" fw={600}>{translate("current_hit_name")}:</Text>
                <Text size="15px" style={{color: theme.colors.dark[2]}}>{currentHit.name}</Text>
              </Flex>
              <Flex gap={8}>
                <Text size="15px" fw={600}>{translate("current_hit_reward")}:</Text>
                <Text size="15px" style={{color: theme.colors.dark[2]}}>{Currency(currentHit.reward, config)}</Text>
              </Flex>
              <span><span style={{fontWeight: 600, fontSize: "15px"}}>{translate("current_hit_description")}:</span> <span style={{fontSize: "15px", color: theme.colors.dark[2]}}>{currentHit.description || "No description"}</span></span>
            </Flex>
          </Flex>
          <span><span style={{fontWeight: 600, fontSize: "15px"}}>{translate("current_hit_objective")}:</span> <span style={{fontSize: "15px", color: theme.colors.dark[2]}}>{currentHit.objective || "No objective."}</span></span>

          {interacting ? (
            <>
              <Button color={"dark.4"} style={{marginTop: "auto"}} onClick={() => {
                setInteracting(false)
                fetchNui("useCamera", {})
              }}>{translate("current_hit_camera")}</Button>
              <Button color={"dark.4"} style={{marginTop: "auto"}} onClick={() => {
                setInteracting(false)
                fetchNui("returnToGame", {})
              }}>{translate("current_hit_return")}</Button>
              <Button color="red" style={{marginTop: "auto"}} onClick={() => {
                setInteracting(false)
                fetchNui("cancelContract", {})
              }}>{translate("current_hit_cancel")}</Button>
            </>
          ) : (
            <Flex align={"center"}>{translate("current_hit_interact_1")} <KeyboardIcon text={"SHIFT"}/> {translate("current_hit_interact_2")}</Flex>
          )}
        </Flex>
      }
    </div>
  );
}

function CameraApp() {
  const [show, setShow] = useState(false)
  const translate = useLocale()
  const [cameraState, setCameraState] = useState<CameraState | null>(null);
  let cameraStateSettings = {
    "idle": {content: (
      <Flex className={"outlined"} style={{fontSize: "30px", fontWeight: 700}} align={"center"}>{translate("camera_state_idle_1")} <KeyboardIcon style={{margin: "0 15px", padding: "15px 15px", fontSize: "20px", textShadow: "none"}} text={"SPACEBAR"}/> {translate("camera_state_idle_2")}</Flex>
    ) },
    "scanning": {content: (
      <Flex className={"outlined"} c={"yellow.4"} style={{fontSize: "30px", fontWeight: 700}} align={"center"}>{translate("camera_state_scanning")}</Flex>
    ) },
    "match": {content: (
      <Flex className={"outlined"} c={"green.4"} style={{fontSize: "30px", fontWeight: 700}} align={"center"}>{translate("camera_state_match")}</Flex>
    ) },
    "no_match": {content: (
      <Flex className={"outlined"} c={"red.4"} style={{fontSize: "30px", fontWeight: 700}} align={"center"}>{translate("camera_state_no_match")}</Flex>
    ) },
  }
  useNuiEvent("setCameraState", function(data) {
    if (data.cameraState) {
      setCameraState(data.cameraState)
      setTimeout(() => {
        setShow(true)
      }, 10)
    }
    else {
      setShow(false)
      setTimeout(() => {
        setCameraState(null)
      }, 200)
    }
  })
  return (
    (cameraState) && (
      <div style={{ backgroundImage: 'url("./images/camera_overlay.png")', overflow: "hidden", position: "absolute", top: "50%", left: "50%", width: "1920px", height: "1080px", transform: "translate(-50%, -50%)", transition: "opacity 0.2s", opacity: (show ? 1.0 : 0), }}>
        <div style={{position: "absolute", bottom: "-275px", left: "50%", transform: "translate(-50%, 0)", transition: "opacity 0.2s", opacity: 1.0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", width: "100%", height: "100%"}}>
          {(cameraState && cameraStateSettings[cameraState]) && (
            cameraStateSettings[cameraState].content
          )}
        </div>
      </div>
    )
  )
}

function App() {
  return (
    <MantineProvider defaultColorScheme='dark' theme={{
      colors: {
      dark: ["rgba(201, 201, 201, 1)", "rgba(184, 184, 184, 1)", "rgba(130, 130, 130, 1)", "rgba(105, 105, 105, 0.9)", "rgba(52, 52, 52, 0.65)", "rgba(26, 26, 26, 0.65)", "rgba(18, 18, 18, 0.65)", "rgba(18, 18, 18, 0.9)", "rgba(0, 0, 0, 0.9)", "rgba(0, 0, 0, 0.9)"],
      },
    }}>
      <ConfigProvider>
      <HitmanAppProvider>
        <HitApp/>
        <OverlayApp/>
        <CameraApp/>
      </HitmanAppProvider>
      </ConfigProvider>
    </MantineProvider>
  )
}

export default App