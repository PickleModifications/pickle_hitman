import { Config, useConfig } from "../config/Config";

export type CurrencyProps = {
    value: number;
}

export function Currency(value: number, config: Config) {
    return new Intl.NumberFormat(config.currency.locale, { style: 'currency', maximumFractionDigits: 0, currency: config.currency.name }).format(value);
}