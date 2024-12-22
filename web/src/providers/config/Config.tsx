import React, { createContext, useContext, useState, ReactNode } from 'react';
import { useNuiEvent } from '../nui/useNui';
import { Position } from '../../App';

type Locale = {
    [key: string]: string;
}

export type Config = {
    loaded?: boolean;
    locale: Locale;
    identifier?: string;
    permissions: {
        placeHits: boolean;
        cancelHits: boolean;
    };
    position: Position;
    defaultPlayerImage: string;
    currency: {
        name: string;
        locale: string;
    };
}

interface ConfigContextProps {
    config: Config;
    setConfig: (newConfig: Config) => void;
}

const ConfigContext = createContext<ConfigContextProps | undefined>(undefined);

interface ConfigProviderProps {
    children: ReactNode;
}

export const ConfigProvider: React.FC<ConfigProviderProps> = ({ children }) => {
    const [config, setConfig] = useState<Config>({
        locale: {},
        // identifier: "hitman:1234",
        permissions: {
            placeHits: true,
            cancelHits: false,
        },
        position: {x: 10, y: 10},
        defaultPlayerImage: "unknown_player.png",
        currency: {
            name: "USD",
            locale: "en-US"
        }
    });

    useNuiEvent("setConfig", function(config) {
        setConfig(config);
    });
    useNuiEvent("updatePermissions", function(data) {
        setConfig({...config, permissions: data.permissions});
    });

    return (
        <ConfigContext.Provider value={{ config, setConfig }}>
            {children}
        </ConfigContext.Provider>
    );
};

export const useConfig = (): ConfigContextProps => {
    const context = useContext(ConfigContext);
    if (!context) {
        throw new Error('useConfig must be used within a ConfigProvider');
    }
    return context;
};