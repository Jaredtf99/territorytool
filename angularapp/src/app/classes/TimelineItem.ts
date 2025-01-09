import { TerritoryInfoTimelineType } from "../enums/TerritoryInfoTimelineType";

export class TimelineItem {
  id?: number;
  date?: Date;
  description?: string;
  type?: TerritoryInfoTimelineType
}
