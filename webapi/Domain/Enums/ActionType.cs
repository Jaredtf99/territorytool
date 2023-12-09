using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Enums
{
    public enum ActionType
    {
        Unknown = 0,
        AddTerritory = 1,
        EditTerritory = 2,
        DeleteTerritory = 3,
        AddUser = 4,
        DeleteUser = 5,
        ChangeUserPassword = 6,
        EditUser = 7,
        AddPerson = 8,
        EditPerson = 9,
        DeletePerson = 10,
        GiveTerritory = 11,
        PickTerritory = 12,

    }
}
