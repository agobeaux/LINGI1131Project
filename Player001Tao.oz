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
   Name = 'Debug001tao'

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
         {TreatStream OutputStream summary(state:off id:ID lives:Input.nbLives sppos:nil pos:nil bombs:Input.nbBombs map:Input.map score:0 mapbombs:nil)}
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
    * Update the list of bombs when a bomb has exploded.
    *
    * @param BombList: list of bombs.
    */
   fun {UpdateBombs BombList Pos}
      fun {DoUpdateBombs BombList Acc}
         case BombList
         of nil then
            Acc
         [] bomb(pos:P)|T then
            if P == Pos then
               {Append Acc T}
            else
               {DoUpdateBombs T {Append Acc [bomb(pos:P)]}}
            end % if
         else
            raise('UpdateBombs : pattern not recognized :'#BombList) end
         end
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
         {Summary.show 'Tried spawning a player that was already on the board in SpawnF.'}
         Summary
      elseif Summary.lives =< 0 then
         RetID = null
         RetSpawn = null
         {System.show 'No more lives left in SpawnF.'}
         Summary
      else
         RetID = Summary.id
         RetSpawn = Summary.sppos
         {AdjoinList Summary [state#on pos#Summary.sppos]}
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
      if Val == 0 orelse Val == 4 then
         true
      else
         false
      end % if
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
         [] bomb(pos:P)|Xr then
            case P
            of pt(x:X y:Y) then
               {DoDangerMap {UpdateDMap Summary.map Map X Y 0 all} Xr}
            else
             raise('Invalid pattern in DangerMap.') end
            end % case P
         end % case BombList
      end % fun DoDangerMap
   in
      {DoDangerMap {ZeroMap Summary.map} Summary.mapbombs}
   end % fun DangerMap

   fun {BestMove List}
      fun {DoBestMove List Best}
         case List
         of nil then
            Best
         [] rec(x:X y:Y val:Val)|T then
            if Val < Best.val then
               {DoBestMove T rec(x:X y:Y val:Val)}
            else
               {DoBestMove T Best}
            end % if
         end % case List
      end % fun DoBestMove
   in
      {DoBestMove List List.1}
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

   /**
    * Determine what action the player should perform.
    * 
    * @param    Summary: summary of the game.
    * @param     ?RetID: unbound, set to ID (or null) by function.
    * @param ?RetAction: unbound, set to the action the player should perform (or null) by function.
    */
   fun {DoAction Summary RetID RetAction}
      if Summary.state == off then
         RetID = null
         RetAction = null
         {System.show 'Off-board player tried to perform an action in DoAction.'}
         Summary
      elseif Summary.bombs =< 0 orelse {OS.rand} mod 10 < 9 then
         local DMap X Y Up Down Left Right Prio NewRec NewPos in
            if Summary.pos \= nil then
               RetID = Summary.id
               X = Summary.pos.x
               Y = Summary.pos.y
               DMap = {DangerMap Summary}

               Up = rec(x:X y:Y-1 val:{Nth {Nth DMap Y-1} X})
               Down = rec(x:X y:Y+1 val:{Nth {Nth DMap Y+1} X})
               Left = rec(x:X-1 y:Y val:{Nth {Nth DMap Y} X-1})
               Right = rec(x:X+1 y:Y val:{Nth {Nth DMap Y} X+1})

               Prio = {RemoveBad [Up Down Left Right] Summary.map}
               NewRec = {BestMove Prio}
               NewPos = pt(x:NewRec.x y:NewRec.y)

               RetAction = move(NewPos)
               {AdjoinList Summary [pos#NewPos]}
            else
               RetID = null
               RetAction = null
               Summary
            end % if
         end % local
      else
         RetID = Summary.id
         RetAction = bomb(Summary.pos)
         {AdjoinList Summary [bombs#Summary.bombs-1]}
      end % if
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
         RetResult = Summary.score
         {System.show 'Tried adding item to off-board player in Add.'}
         Summary
      else
         case Type
         of bomb then
            RetResult = Summary.bombs + Option
            {AdjoinList Summary [bombs#RetResult]}
         [] point then
            RetResult = Summary.score+ Option
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
         RetResult = null
         {System.show 'Off-board player received gotHit message in GotHit.'}
         Summary
      elseif Summary.lives =< 0 then
         RetID = null
         RetResult = null
         {System.show 'Dead player received gotHit message in GotHit.'}
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
         Summary
      [] deadPlayer(ID) then
         Summary
      [] bombPlanted(BPPos) then
         local NewBombList in
            NewBombList = {Append Summary.mapbombs [bomb(pos:BPPos)]}
            {AdjoinList Summary [mapbombs#NewBombList]}
         end % local
      [] bombExploded(BEPos) then
         {AdjoinList Summary [mapbombs#{UpdateBombs Summary.mapbombs BEPos}]}
      [] boxRemoved(BRPos) then
         local NewMap in
            NewMap = {UpdateMap Summary.map BRPos.x BRPos.y 0}
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
