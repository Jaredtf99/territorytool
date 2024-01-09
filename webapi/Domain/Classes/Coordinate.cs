using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class Coordinate
    {
        public Coordinate(decimal latitude, decimal longitude) 
        {
            this.Latitude = latitude;
            this.Longitude = longitude;
        }

        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
    }
}
