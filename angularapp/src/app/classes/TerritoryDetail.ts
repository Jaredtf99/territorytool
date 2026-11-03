import { DeliveryFormat } from "../enums/DeliveryFormat";
import { TimelineItem } from "./TimelineItem";

export class TerritoryDetail {
  id?: number;
  code?: string;
  name?: string;
  mapUrl?: string;
  imgUrl?: string;
  personName?: string;
  lastPickedDateUtc?: Date;
  givenDateUtc?: Date;
  deliveryFormat?: DeliveryFormat;
  pickedCount?: number;
  lastUser?: string;
  timelineItems?: TimelineItem[];
}
