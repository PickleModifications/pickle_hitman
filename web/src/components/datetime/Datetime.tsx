export function Datetime(date: number, locale?: string): string {
    const dateString = new Intl.DateTimeFormat(locale || 'en-US', {
        dateStyle: "short",
      }).format(date * 1000);
    const timeString = new Intl.DateTimeFormat(locale || 'en-US', {
        timeStyle: "short",
      }).format(date * 1000);
    return `${dateString} ${timeString}`;
}