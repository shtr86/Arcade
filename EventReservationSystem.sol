// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";  // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";  // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol

contract EventsSystem is Ownable {


    struct Event {
        uint EventID;
        uint StartDate; // Start of EventDurationHours
        uint FinishDate;    // End of EventDurationHours
        uint SignUpDurationMinutes; // 24
        uint EventDurationMinutes; // This is only calculated for conflicts
        uint ComplainDurationMinutes; // 12
        uint ValidationDurationMinutes;   // 12
        uint daysCount;
        uint playerCount;
    }


    uint internal lastEventID;

    uint private StressTestLimit=300;

    uint immutable ZeroDate;

    mapping (uint => mapping(uint => uint[2])) EventRangesAtDay; // eventID => dayID => [startRangeDate, FinishRangeDate]
    mapping (uint => uint[]) dayIDToEventIDS;
    mapping (uint => uint) dayIDReserveAmount;
    mapping (uint => Event) eventsByID;

    

    Event[] internal events;

    constructor() {
        ZeroDate = (block.timestamp/86400)*86400; // set to 00:00 of the deployment date
    }

    function DayID(uint compareDate, uint zeroDate) public pure returns(uint) {
        return (compareDate - zeroDate)/86400; // returns days count between ZeroDate and comparedDate
    }

    function EventsCAtDay(uint dayID) public view returns(uint)  {
        return dayIDReserveAmount[dayID]; // returns days count between ZeroDate and comparedDate
    }

    function ReservedAtDayIDWithRange(uint dayID, uint StartDate, uint FinishDate) public view returns(uint)  {
        uint totalAtRange = 0;
        uint tmpEventID = 0;
        for (uint i=0; i<dayIDToEventIDS[dayID].length; i++) {
            tmpEventID = dayIDToEventIDS[dayID][i];

            if ((EventRangesAtDay[tmpEventID][dayID][0] >= StartDate && EventRangesAtDay[tmpEventID][dayID][0] < FinishDate) || (EventRangesAtDay[tmpEventID][dayID][1] <= FinishDate && EventRangesAtDay[tmpEventID][dayID][1] > StartDate)) {
                totalAtRange += eventsByID[tmpEventID].playerCount;
            }
        }

        return totalAtRange;
    }

    function NewEvent(uint StartDate, uint FinishDate, uint32 SignUpDurationMinutes) public {
        lastEventID = events.length;
        events.push();

        require(FinishDate > StartDate, "Wrong Dates!");

        Event storage tmpEvent = events[lastEventID];

        tmpEvent.EventID = lastEventID;
        tmpEvent.StartDate = StartDate;
        tmpEvent.FinishDate = FinishDate;
        tmpEvent.SignUpDurationMinutes = SignUpDurationMinutes;
        tmpEvent.EventDurationMinutes = (FinishDate - StartDate) / 60;
        tmpEvent.ComplainDurationMinutes = 720;
        tmpEvent.ValidationDurationMinutes = 720;
        tmpEvent.playerCount = 100;

        eventsByID[lastEventID] = tmpEvent;

        uint todayStartDate = StartDate;
        uint todayFinishDate = ((todayStartDate + 86400) / 86400) * 86400;
        uint LeftDuration = (FinishDate - StartDate);
        uint dayID = DayID(todayStartDate, ZeroDate);
        uint[2] storage Range = EventRangesAtDay[lastEventID][dayID];
        uint loopC = ((FinishDate - StartDate) / 86400) + 2;

        for (uint8 CurrentDay=1; CurrentDay<=loopC; CurrentDay++) { // reserve operation
            if (LeftDuration >= (todayFinishDate-todayStartDate)) {
                require((ReservedAtDayIDWithRange(dayID, todayStartDate, todayFinishDate) + tmpEvent.playerCount) <= StressTestLimit, "Not enough reserve amount left!"); 

                dayIDToEventIDS[dayID].push(lastEventID);
                dayIDReserveAmount[dayID] += tmpEvent.playerCount;

                Range[0] = todayStartDate;
                Range[1] = todayFinishDate;

                todayStartDate = todayFinishDate;
                todayFinishDate = ((todayStartDate + 86400) / 86400) * 86400;
                LeftDuration = LeftDuration - (todayFinishDate - todayStartDate);
                dayID = DayID(todayStartDate, ZeroDate);
                Range = EventRangesAtDay[lastEventID][dayID];
            } else {
                if (LeftDuration > 0) {
                    require((ReservedAtDayIDWithRange(dayID, todayStartDate, FinishDate) + tmpEvent.playerCount) <= StressTestLimit, "Not enough reserve amount left!"); 

                    dayIDToEventIDS[dayID].push(lastEventID);
                    dayIDReserveAmount[dayID] += tmpEvent.playerCount;
                    
                    Range[0] = todayStartDate;
                    Range[1] = FinishDate;
                    
                    tmpEvent.daysCount = CurrentDay;
                } else {
                    tmpEvent.daysCount = CurrentDay-1;
                }

                break;
            }
        }


    }
}