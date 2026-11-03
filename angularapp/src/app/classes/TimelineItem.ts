import { DeliveryFormat } from "../enums/DeliveryFormat";
import { TerritoryInfoTimelineType } from "../enums/TerritoryInfoTimelineType";

export class TimelineItem {
  id?: number;
  date?: Date;
  description?: string;
  type?: TerritoryInfoTimelineType
  deliveryFormat?: DeliveryFormat;
}
