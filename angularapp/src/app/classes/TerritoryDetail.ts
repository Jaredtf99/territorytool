import { TimelineItem } from "./TimelineItem";

export class TerritoryDetail {
  id?: number;
  code?: string;
  name?: string;
  mapUrl?: string;
  imgUrl?: string;
  personName?: string;
  givenDateUtc?: Date;
  timelineItems?: TimelineItem[];
}
