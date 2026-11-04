import { DeliveryFormat } from "../enums/DeliveryFormat";

/** Ficha de hermano tal y como la devuelve la RPC `get_person_detail`. */
export interface PersonDetail {
  generatedAt: Date;
  person: PersonDetailProfile;
  summary: PersonDetailSummary;
  current: PersonCurrentAssignment[];
  activity: PersonMonthlyActivity[];
  topTerritories: PersonTopTerritory[];
  history: PersonAssignment[];
}

export interface PersonDetailProfile {
  id: number;
  name: string;
  enabled: boolean;
  createdAt?: Date;
}

export interface PersonDetailSummary {
  totalAssignments: number;
  activeAssignments: number;
  completedAssignments: number;
  uniqueTerritories: number;
  virtualAssignments: number;
  averageHoldingDays: number | null;
  congregationAverageHoldingDays: number | null;
  longestHoldingDays: number | null;
  firstAssignmentAt?: Date;
  lastAssignmentAt?: Date;
  lastReturnAt?: Date;
  assignmentsLastYear: number;
  activityRank: number | null;
  activePersonsCount: number;
}

export interface PersonCurrentAssignment {
  transactionId: number;
  territoryId: number;
  territoryCode: string;
  territoryName: string;
  givenAt: Date;
  days: number;
  deliveryFormat: DeliveryFormat;
  givenBy?: string;
}

export interface PersonMonthlyActivity {
  month: Date;
  givenCount: number;
  returnedCount: number;
}

export interface PersonTopTerritory {
  territoryId: number;
  territoryCode: string;
  territoryName: string;
  times: number;
  totalDays: number;
  lastGivenAt?: Date;
}

export interface PersonAssignment {
  transactionId: number;
  territoryId: number;
  territoryCode: string;
  territoryName: string;
  givenAt: Date;
  pickedAt?: Date;
  days: number;
  deliveryFormat: DeliveryFormat;
  givenBy?: string;
  pickedBy?: string;
}
