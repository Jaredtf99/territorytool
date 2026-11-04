import { DeliveryFormat } from "../enums/DeliveryFormat";
import { TimelineItem } from "./TimelineItem";

export class TerritoryDetail {
  id?: number;
  code?: string;
  name?: string;
  mapUrl?: string;
  imgUrl?: string;
  personId?: number;
  personName?: string;
  lastPickedDateUtc?: Date;
  givenDateUtc?: Date;
  deliveryFormat?: DeliveryFormat;
  excludeFromSuggestions?: boolean;
  pickedCount?: number;
  lastUser?: string;
  timelineItems?: TimelineItem[];
}
