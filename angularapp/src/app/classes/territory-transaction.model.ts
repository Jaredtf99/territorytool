export class TerritoryTransaction {
    transactionId: number = 0;
    territoryId: number =0;
    personId: number = 0;
    personName: string = "";
    territoryName: string = "";
    givenDateUtc: Date = new Date();
    isAutomaticGivenDate: boolean = false;
    givenBy: string = "";
    pickedDateUtc?: Date;
    isAutomaticPickedDate?: boolean;
    pickedBy?: string;
} 