import React, { createContext, useContext, useState, ReactNode } from 'react';
import { useNuiEvent } from '../nui/useNui';
import { Hit } from '../../components/hitspage/HitsPage';
import { CurrentHit } from '../../App';

type Locale = {
    [key: string]: string;
}

type HitAppData = {
    currentHit: CurrentHit | null;
    hits: Hit[];
}

interface HitAppContextProps {
    hitmanApp: HitAppData;
    setHitmanApp: (newHitApp: HitAppData) => void;
}

const HitAppContext = createContext<HitAppContextProps | undefined>(undefined);

interface HitAppProviderProps {
    children: ReactNode;
}

export const HitmanAppProvider: React.FC<HitAppProviderProps> = ({ children }) => {
    const [hitmanApp, setHitmanApp] = useState<HitAppData>({
        currentHit: null,
        hits: [],    
    });
    useNuiEvent("updateHits", function(data) {
        hitmanApp.hits = data.hits;
        setHitmanApp(hitmanApp);
    });
    useNuiEvent("setCurrentHit", function(data) {
        hitmanApp.currentHit = data.hit;
        setHitmanApp(hitmanApp);
    });
    return (
        <HitAppContext.Provider value={{ hitmanApp, setHitmanApp }}>
            {children}
        </HitAppContext.Provider>
    );
};

export const useHitmanApp = (): HitAppContextProps => {
    const context = useContext(HitAppContext);
    if (!context) {
        throw new Error('useHitmanApp must be used within a HitmanAppProvider');
    }
    return context;
};