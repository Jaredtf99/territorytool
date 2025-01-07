export class TerritoryTransaction {
    transactionId: number = 0;
    territoryId: number =0;
    personId: number = 0;
    personName: number = 0;
    givenDateUtc: Date = new Date();
    isAutomaticGivenDate: boolean = false;
    givenBy: string = "";
    pickedDateUtc?: Date;
    isAutomaticPickedDate?: boolean;
    pickedBy?: string;
} 