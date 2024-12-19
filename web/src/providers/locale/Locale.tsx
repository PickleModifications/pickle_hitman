import { useConfig } from "../config/Config";

export function useLocale() {
    const { config } = useConfig();
    return (key: string, ...args: any) => {
        if (config.locale && config.locale[key]) {
            return config.locale[key].replace(/%s/g, function() {
                return args.shift();
            });
        }
        return key;
    };
}
