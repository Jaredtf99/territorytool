import { DeliveryFormat } from "../enums/DeliveryFormat";

export class Territory {
  id?: number;
  code?: string;
  name?: string;
  mapUrl?: string;
  imgUrl?: string;
  personId?: number;
  personName?: string;
  givenDateUtc?: Date;
  lastPickedDateUtc?: Date;
  deliveryFormat?: DeliveryFormat;
  excludeFromSuggestions?: boolean;
}
