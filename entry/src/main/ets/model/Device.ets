export class Device {
  id: number = 0;
  name: string = '';
  icon: string = 'other';
  sortOrder: number = 0;
  archived: boolean = false;
  createdAt: number = 0;
}

export const DEVICE_ICON_KEYS: string[] = ['ev', 'powerbank', 'phone', 'earphone', 'laptop', 'other'];

export function iconToResource(icon: string): Resource {
  switch (icon) {
    case 'ev':
      return $r('app.media.ic_device_ev');
    case 'powerbank':
      return $r('app.media.ic_device_powerbank');
    case 'phone':
      return $r('app.media.ic_device_phone');
    case 'earphone':
      return $r('app.media.ic_device_earphone');
    case 'laptop':
      return $r('app.media.ic_device_laptop');
    case 'other':
      return $r('app.media.ic_device_other');
    default:
      return $r('app.media.ic_device_other');
  }
}

export function iconToNameRes(icon: string): Resource {
  switch (icon) {
    case 'ev':
      return $r('app.string.device_type_ev');
    case 'powerbank':
      return $r('app.string.device_type_powerbank');
    case 'phone':
      return $r('app.string.device_type_phone');
    case 'earphone':
      return $r('app.string.device_type_earphone');
    case 'laptop':
      return $r('app.string.device_type_laptop');
    case 'other':
      return $r('app.string.device_type_other');
    default:
      return $r('app.string.device_type_other');
  }
}
