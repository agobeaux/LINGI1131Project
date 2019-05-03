functor
import
   Input
   Browser
   Projet2019util
   OS
   System
export
   portPlayer:StartPlayer
define
   % Main functions.
   StartPlayer
   TreatStream

   % ?
   Name = 'debug001turing'

   % Handler functions.
   GetId
   GetState
   AssignSpawn
   SpawnF
   DoAction
   Add
   GotHit
   Info

   % Helper functions.
   UpdateMap
   SetNth
   UpdateBombs
   AddValMap
   ZeroMap
   IsGoodMap
   UpdateDMap
   DangerMap
   BestMove
   RemoveBad
   NextToBox
   Value
   BFS
   RandomNeighbour
   RemoveSeen
   BFSNeighbours

   % Global variables
   GoodValues = [0 4 5 6]
in
   /**
    * Initializes the player and launches it.
    *
    * @param ID: current player's <bomber> ID.
    */
   fun {StartPlayer ID}
      Stream Port OutputStream
   in
      thread % Filter to test validity of message sent to the player.
         OutputStream = {Projet2019util.portPlayerChecker Name ID Stream}
      end % thread
      {NewPort Stream Port}
      thread
         % The player is initially off the board and has no spawn position, until (assign)spawn.
         {TreatStream OutputStream summary(state:off id:ID lives:Input.nbLives sppos:nil pos:nil bombs:Input.nbBombs map:Input.map score:0 bomblist:nil)}
      end % thread
      Port
   end % fun StartPlayer


   /**
    * Set the nth value of a list to a given value.
    *
    * @param  Xs: list.
    * @param   N: index of the value that should be changed.
    * @param Val: new value of the changed element.
    */
   fun {SetNth Xs N Val}
      fun {DoSetNth Xs N Val Acc}
         if N == 0 then
            {Append Acc [Val]}|Xs.2
         else
            {DoSetNth Xs.2 N-1 Val {Append Acc [Xs.1]}}
         end % if
      end % fun DoSetNth
   in
      {DoSetNth Xs N Val nil}
   end % fun SetNth

   /**
    * Update the list of bombs after a turn has passed.
    *
    * @param BombList: list of bombs.
    */
   fun {UpdateBombs BombList}
      fun {DoUpdateBombs BombList Acc}
         case BombList
         of nil then
            Acc
         [] bomb(pos:P time:Time)|T then
            if Time == 0 then
               {DoUpdateBombs T Acc}
            else
               {DoUpdateBombs T {Append Acc [bomb(pos:P time:Time-1)]}}
            end % if
         [] bomb(pos:P time:T) then
            if Time == 0 then
               Acc
            else
               {Append Acc [bomb(pos:P time:T)]}
            end % if
         end % case BombList
      end % fun DoUpdateBombs
   in
      {DoUpdateBombs BombList nil}
   end % fun UpdateBombs

   /**
    * Change a specified tile's value.
    *
    * @param   Map: the map of the game.
    * @param     X: the x value of the tile.
    * @param     Y: the y value of the tile.
    * @param Value: the new value of the tile.
    */
   fun {UpdateMap Map X Y Value}
      fun {NewRow Row X ThisX}
         case Row
         of H|T then
            if X == ThisX then
               Value|T
            else
               H|{NewRow T X ThisX+1}
            end % if
         else
            raise('Error in NewRow function: Row != H|T.') end
         end % case Row
      end % fun NewRow
      fun {NewColumns Map X Y ThisY}
         case Map
         of H|T then
            if ThisY == Y then
               {NewRow H X 1}|T
            else
               H|{NewColumns T X Y ThisY+1}
            end % if
         else
            raise('Error in NewColumns function: Row != H|T.') end
            % raise('Error in NewColumns function: Map != H|T in TerenceTao.') end
         end % case Map
      end % fun NewColumns
   in
      % Works if 1 < X, Y < N, 1 and N being the borders.
      if X < 1 orelse Y < 1 orelse Y > Input.nbRow orelse X > Input.nbColumn then
         raise('Assertion error in UpdateMap function') end
      end % if
      {NewColumns Map X Y 1}
   end % fun UpdateMap

   /**
    * Bind the ID of the player.
    * 
    * @param Summary: summary of the game.
    * @param  ?RetID: unbound, set to ID by function.
    */
   fun {GetId Summary RetID}
      RetID = Summary.id
      Summary
   end % fun GetId

   /**
    * Bind the ID and State of the player.
    *
    * @param   Summary: summary of the game.
    * @param    ?RetID: unbound, set to ID by function.
    * @param ?RetState: unbound, set to State by function.
    */
   fun {GetState Summary RetID RetState}
      RetID = Summary.id
      RetState = Summary.state
      Summary
   end % fun GetState

   /**
    * Assign a spawn position.
    * 
    * @param Summary: summary of the game.
    * @param   SpPos: Spawn position of the current player.
    */
   fun {AssignSpawn Summary SpPos}
      {AdjoinList Summary [sppos#SpPos]}
   end % fun AssignSpawn

   /**
    * Spawn the player in its assigned position if possible, i.e.:
    *  - the player has lives left;
    *  - the player is not already on the board.
    * If any of these conditions are not met, then null is returned for both the ID and Pos.
    *
    * @param Summary: summary of the game.
    * @param  ?RetID: unbound, set to ID (or null) by function.
    * @param ?RetPos: unbound, set to SpawnPos (or null) by function.
    */
   fun {SpawnF Summary RetID RetSpawn}
      if Summary.state == on then
         RetID = null
         RetSpawn = null
         raise('Tried spawning a player that was already on the board in SpawnF.') end
      elseif Summary.lives =< 0 then
         RetID = null
         RetSpawn = null
         raise('No more lives left in SpawnF.') end
      else
         RetID = Summary.id
         RetSpawn = Summary.sppos
         {AdjoinList Summary [state#on pos#Summary.sppos score#0]}
      end % if
   end % fun SpawnF

   fun {AddValMap Map X Y Val}
      {UpdateMap Map X Y Val+{Nth {Nth Map Y} X}}
   end % fun AddValMap

   fun {ZeroMap Map}
      fun {DoZeroMap Map X Y}
         if X > Input.nbColumn then
            if Y == Input.nbRow then
               Map
            else
               {DoZeroMap Map 1 Y+1}
            end % if
         else
            {DoZeroMap {UpdateMap Map X Y 0} X+1 Y}
         end % if
      end % fun DoZeroMap
   in
      {DoZeroMap Map 1 1}
   end % fun ZeroMap

   fun {IsGoodMap Val}
      {List.member Val GoodValues}
   end % fun IsGoodMap

   fun {UpdateDMap Map DMap X Y Dist Dir}
      if X =< 1 orelse Y =< 1 orelse X >= Input.nbColumn orelse Y >= Input.nbRow orelse Dist > Input.fire orelse {Not {IsGoodMap {Nth {Nth Map Y} X}}} then
         DMap
      else
         % We're either already checking in a given direction, in which case we continue,
         % or we're still on the bomb's position, in which case we have to explore all directions.
         if Dir == up then
            {UpdateDMap Map {AddValMap DMap X Y Input.fire-Dist} X Y-1 Dist+1 up} % Moving up.
         elseif Dir == down then
            {UpdateDMap Map {AddValMap DMap X Y Input.fire-Dist} X Y+1 Dist+1 down} % Moving down.
         elseif Dir == left then
            {UpdateDMap Map {AddValMap DMap X Y Input.fire-Dist} X-1 Y Dist+1 left} % Moving left.
         elseif Dir == right then
            {UpdateDMap Map {AddValMap DMap X Y Input.fire-Dist} X+1 Y Dist+1 right} % Moving right.
         else DMap1 DMap2 DMap3 in
            DMap1 = {UpdateDMap Map {AddValMap DMap X Y Input.fire} X Y-1 Dist+1 up} % First branch.
            DMap2 = {UpdateDMap Map DMap1 X Y+1 Dist+1 down} % Second branch.
            DMap3 = {UpdateDMap Map DMap2 X-1 Y  Dist+1 left} % Third branch.
            {UpdateDMap Map DMap3 X+1 Y Dist+1 right} % Final branch.
         end % if
      end % if
   end % fun UpdateDMap

   fun {DangerMap Summary}
      fun {DoDangerMap Map BombList}
         case BombList
         of nil then
            Map
         [] bomb(pos:P time:T) then
            case P
            of pt(x:X y:Y) then
               {UpdateDMap Summary.map Map X Y 0 all}
            else
             raise('Invalid pattern in DangerMap.') end
            end % case P
         [] bomb(pos:P time:T)|Xr then
            case P
            of pt(x:X y:Y) then
               {DoDangerMap {UpdateDMap Summary.map Map X Y 0 all} Xr}
            else
             raise('Invalid pattern in DangerMap.') end
            end % case P
         end % case BombList
      end % fun DoDangerMap
   in
      {DoDangerMap {ZeroMap Summary.map} Summary.bomblist}
   end % fun DangerMap

   fun {BestMove List BFSRes}
      fun {DoBestMove List Best BFSRes}
         case List
         of nil then
            Best
         [] rec(x:X y:Y val:Val)|T then
            if Val < Best.val orelse (Val == Best.val andthen X == BFSRes.x andthen Y == BFSRes.y) then
               {DoBestMove T rec(x:X y:Y val:Val) BFSRes}
            else
               {DoBestMove T Best BFSRes}
            end % if
         end % case List
      end % fun DoBestMove
   in
      {DoBestMove List List.1 BFSRes}
   end % fun BestMove

   fun {RemoveBad L Map}
      fun {DoRemoveBad L Map Acc}
         case L
         of nil then
            Acc
         [] rec(x:X y:Y val:Val)|T then
            if {IsGoodMap {Nth {Nth Map Y} X}} then
               {DoRemoveBad T Map {Append Acc [rec(x:X y:Y val:Val)]}}
            else
               {DoRemoveBad T Map Acc}
            end % if
         end % case L
      end % fun DoRemoveBad
   in
      {DoRemoveBad L Map nil}
   end % fun RemoveBad

   fun {NextToBox PosList ValList}
      case PosList
      of nil then
         false
      [] rec(x:X y:Y val:Val)|T then
         if {List.member Val ValList} then
            true
         else
            {NextToBox T ValList}
         end % if
      end % case PosList
   end % fun NextToBox

   fun {Value Map X Y}
      {Nth {Nth Map Y} X}
   end % fun Value

   fun {RemoveSeen L Seen}
      fun {DoRemoveSeen L Seen Acc}
         case L
         of nil then
            Acc
         [] node(x:X y:Y dist:D)|T then
            if {Value Seen X Y} == 1 then
               {DoRemoveSeen T Seen Acc}
            else
               {DoRemoveSeen T Seen {Append Acc [node(x:X y:Y dist:D)]}}
            end % if
         end % case L
      end % fun DoRemoveSeen
   in
      {DoRemoveSeen L Seen nil}
   end % fun RemoveSeen

   fun {BFS Map Start Target}
      fun {DoBFS Map Start Queue Seen Target}
         case Queue
         of nil then
            {System.show 'notarget'}
            {System.show Start}
            notarget
         [] node(x:X y:Y dist:D)|T then
            if X =< 1 orelse X >= Input.nbColumn orelse Y =< 1 orelse Y >= Input.nbRow orelse {Not {IsGoodMap {Value Map X Y}}} then
               {DoBFS Map Start T {UpdateMap Seen X Y 1} Target}
            elseif {Value Map X Y} == Target then
               D
            else
               {DoBFS Map Start {Append T {RemoveSeen [node(x:X+1 y:Y dist:D+1) node(x:X y:Y+1 dist:D+1) node(x:X y:Y-1 dist:D+1) node(x:X-1 y:Y dist:D+1)] Seen}} {UpdateMap Seen X Y 1} Target}
            end % if
         end % case Queue
      end % fun DoBFS
   in
      {DoBFS Map Start [node(x:Start.x y:Start.y dist:0)] {UpdateMap {ZeroMap Map} Start.x Start.y 1} Target}
   end % fun BFS

   fun {RandomNeighbour X Y}
      local Rand1 in
         Rand1 = {OS.rand} mod 4
         case Rand1
         of 0 then pt(x:X+1 y:Y)
         [] 1 then pt(x:X-1 y:Y)
         [] 2 then pt(x:X y:Y+1)
         [] 3 then pt(x:X y:Y-1)
         end % case Rand1
      end % local
   end % fun RandomNeighbour

   fun {BFSNeighbours Map X Y Target Val}
      if {BFS Map pt(x:X y:Y-1) Target} == Val - 1 then
         pt(x:X y:Y-1)
      elseif {BFS Map pt(x:X y:Y+1) Target} == Val - 1 then
         pt(x:X y:Y+1)
      elseif {BFS Map pt(x:X-1 y:Y) Target} == Val - 1 then
         pt(x:X-1 y:Y)
      else
         pt(x:X+1 y:Y)
      end % if
   end % fun BFSNeighbours

   /**
    * Determine what action the player should perform.
    * 
    * @param OldSummary: summary of the game.
    * @param     ?RetID: unbound, set to ID (or null) by function.
    * @param ?RetAction: unbound, set to the action the player should perform (or null) by function.
    */
   fun {DoAction OldSummary RetID RetAction}
      local Summary in 
         Summary = {AdjoinList OldSummary [bomblist#{UpdateBombs OldSummary.bomblist}]}
         if Summary.state == off then
            RetID = null
            RetAction = null
            raise('Off-board player tried to perform an action in DoAction.') end
            Summary
         elseif Summary.bombs =< 0 then
            local DMap X Y Up Down Left Right Prio NewRec NewPos BFSPoint BFSBonus in
               if Summary.pos \= nil then 
                  X = Summary.pos.x
                  Y = Summary.pos.y
                  DMap = {DangerMap Summary}

                  Up = rec(x:X y:Y-1 val:{Nth {Nth DMap Y-1} X})
                  Down = rec(x:X y:Y+1 val:{Nth {Nth DMap Y+1} X})
                  Left = rec(x:X-1 y:Y val:{Nth {Nth DMap Y} X-1})
                  Right = rec(x:X+1 y:Y val:{Nth {Nth DMap Y} X+1})

                  Prio = {RemoveBad [Up Down Left Right] Summary.map}
                  BFSBonus = {BFS Summary.map pt(x:X y:Y) 6}
                  BFSPoint = {BFS Summary.map pt(x:X y:Y) 5}

                  if BFSBonus == notarget andthen BFSPoint == notarget then
                     NewRec = {BestMove Prio {RandomNeighbour X Y}}
                  elseif BFSBonus == notarget then
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 5 BFSPoint}}
                  elseif BFSPoint == notarget then
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 6 BFSBonus}}
                  elseif BFSBonus > 2 * BFSPoint then
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 5 BFSPoint}}
                  else
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 6 BFSBonus}}
                  end % if
                  NewPos = pt(x:NewRec.x y:NewRec.y)

                  RetAction = move(NewPos)
                  {AdjoinList Summary [pos#NewPos]}
               else
                  Summary
               end % if
            end % local
         else DMap X Y UpM DownM LeftM RightM in
            if Summary.pos \= nil then 
               X = Summary.pos.x
               Y = Summary.pos.y
               DMap = {DangerMap Summary}

               UpM = rec(x:X y:Y-1 val:{Nth {Nth Summary.map Y-1} X})
               DownM = rec(x:X y:Y+1 val:{Nth {Nth Summary.map Y+1} X})
               LeftM = rec(x:X-1 y:Y val:{Nth {Nth Summary.map Y} X-1})
               RightM = rec(x:X+1 y:Y val:{Nth {Nth Summary.map Y} X+1})

               if {NextToBox [UpM DownM LeftM RightM] [2 3]} then
                  RetID = Summary.id
                  RetAction = bomb(Summary.pos)
                  {AdjoinList Summary [bombs#Summary.bombs-1]}
               else Up Down Left Right Prio NewRec NewPos BFSPoint BFSBonus in
                  Up = rec(x:X y:Y-1 val:{Nth {Nth DMap Y-1} X})
                  Down = rec(x:X y:Y+1 val:{Nth {Nth DMap Y+1} X})
                  Left = rec(x:X-1 y:Y val:{Nth {Nth DMap Y} X-1})
                  Right = rec(x:X+1 y:Y val:{Nth {Nth DMap Y} X+1})

                  Prio = {RemoveBad [Up Down Left Right] Summary.map}
                  BFSBonus = {BFS Summary.map pt(x:X y:Y) 6}
                  BFSPoint = {BFS Summary.map pt(x:X y:Y) 5}

                  if BFSBonus == notarget andthen BFSPoint == notarget then
                     NewRec = {BestMove Prio {RandomNeighbour X Y}}
                  elseif BFSBonus == notarget then
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 5 BFSPoint}}
                  elseif BFSPoint == notarget then
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 6 BFSBonus}}
                  elseif BFSBonus > 2 * BFSPoint then
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 5 BFSPoint}}
                  else
                     NewRec = {BestMove Prio {BFSNeighbours Summary.map X Y 6 BFSBonus}}
                  end % if
                  NewPos = pt(x:NewRec.x y:NewRec.y)

                  RetAction = move(NewPos)
                  {AdjoinList Summary [pos#NewPos]}
               end % if
            else
               Summary
            end % if
         end % if

      end % local
   end % fun DoAction

   /**
    * Add an item to the player.
    *
    * @param    Summary: summary of the game.
    * @param       Type: the type of the item.
    * @param     Option: the value of the item.
    * @param ?RetResult: unbound, new value of the counter.
    */
   fun {Add Summary Type Option RetResult}
      if Summary.state == off then
         RetResult = 69
         raise('Tried adding item to off-board player in Add.') end
         Summary
      else
         case Type
         of bomb then
            RetResult = Summary.bombs + Option
            {AdjoinList Summary [bombs#RetResult]}
         [] point then
            RetResult = Summary.score+1
            {AdjoinList Summary [score#RetResult]}
         else
            RetResult = 69
            raise('Unknown type in Add.') end
            Summary
         end % case Type
      end % if
   end % fun Add

   /**
    * Handle getting hit by fire.
    * 
    * @param    Summary: summary of the game.
    * @param     ?RetID: unbound, <bomber> ID of the player.
    * @param ?RetResult: unbound, result of getting hit.
    */
   fun {GotHit Summary RetID RetResult}
      if Summary.state == off then
         RetID = null
         RetResult = off
         raise('Off-board player received gotHit message in GotHit.') end
         Summary
      elseif Summary.lives =< 0 then
         RetID = null
         RetResult = off
         raise('Dead player received gotHit message in GotHit.') end
         Summary
      else NewLives in
         RetID = Summary.id
         NewLives = Summary.lives - 1
         RetResult = death(NewLives)
         {AdjoinList Summary [state#off lives#NewLives]}
      end % if
   end % fun GotHit

   /**
    * Handle informational messages.
    *
    * @param Summary: summary of the game.
    * @param Message: informational message being handled.
    */
   fun {Info Summary Message}
      case Message
      of spawnPlayer(ID SPPos) then
         Summary
      [] movePlayer(ID MPPos) then
         if {List.member {Nth {Nth Summary.map MPPos.y} MPPos.x} [5 6]} then
            {AdjoinList Summary [map#{UpdateMap Summary.map MPPos.x MPPos.y 0}]}
         else
            Summary
         end % if
      [] deadPlayer(ID) then
         Summary
      [] bombPlanted(BPPos) then
         local NewBombList in
            NewBombList = {Append Summary.bomblist [bomb(pos:BPPos time:Input.timingBomb)]}
            {AdjoinList Summary [bomblist#NewBombList]}
         end % local
      [] bombExploded(BEPos) then
         Summary
      [] boxRemoved(BRPos) then
         local NewMap in
            case {Nth {Nth Summary.map BRPos.y} BRPos.x}
            of 2 then NewMap = {UpdateMap Summary.map BRPos.x BRPos.y 5} % Tile with point.
            [] 3 then NewMap = {UpdateMap Summary.map BRPos.x BRPos.y 6} % Tile with bonus.
            end % case {Nth ...}
            {AdjoinList Summary [map#NewMap]}
         end % local
      end % case Message
   end % fun Info

   /**
    * Read the current stream to determine actions.
    *
    * @param  Stream: input stream of bomber messages.
    * @param Summary: summary of the game.
    */
   proc {TreatStream Stream Summary}
      case Stream
      of nil then skip
      [] getId(RetID)|S then
         {TreatStream S {GetId Summary RetID}}
      [] getState(RetID RetState)|S then
         {TreatStream S {GetState Summary RetID RetState}}
      [] assignSpawn(SpPos)|S then
         {TreatStream S {AssignSpawn Summary SpPos}}
      [] spawn(RetID RetPos)|S then
         {TreatStream S {SpawnF Summary RetID RetPos}}
      [] doaction(RetID RetAction)|S then
         {TreatStream S {DoAction Summary RetID RetAction}}
      [] add(Type Option RetResult)|S then
         {TreatStream S {Add Summary Type Option RetResult}}
      [] gotHit(RetID RetResult)|S then
         {TreatStream S {GotHit Summary RetID RetResult}}
      [] info(Message)|S then
         {TreatStream S {Info Summary Message}}
      else
         skip
      end % case Stream
   end % proc TreatStream
end % functor
