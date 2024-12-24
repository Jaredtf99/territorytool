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
  pickedCount?: number;
  lastUser?: string;
  timelineItems?: TimelineItem[];
}
