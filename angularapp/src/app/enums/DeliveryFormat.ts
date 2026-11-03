export type DeliveryFormat = 'physical' | 'virtual';

export const DELIVERY_FORMAT_LABELS: Record<DeliveryFormat, string> = {
  physical: 'Físico',
  virtual: 'Virtual'
};

export const DELIVERY_FORMAT_ICONS: Record<DeliveryFormat, string> = {
  physical: 'fa-solid fa-file-lines',
  virtual: 'fa-solid fa-mobile-screen'
};

export function parseDeliveryFormat(value: unknown): DeliveryFormat {
  return value === 'virtual' ? 'virtual' : 'physical';
}
