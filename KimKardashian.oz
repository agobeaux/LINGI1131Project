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
   Name = 'namefordebug'

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

   % Global immutable variables.
   ID % Player's <bomber> ID.
   SpawnPos % Spawn position of the player.
in
   /**
    * Initializes the player and launches it.
    *
    * @param FID: current player's <bomber> ID.
    */
   fun {StartPlayer FID}
      Stream Port OutputStream
   in
      thread % Filter to test validity of message sent to the player.
         OutputStream = {Projet2019util.portPlayerChecker Name FID Stream}
      end % thread
      {NewPort Stream Port}
      thread
         % The player is initially off the board and has no spawn position, until (assign)spawn.
         ID = FID
	      {TreatStream OutputStream off Input.nbLives null Input.nbBombs Input.Map 0}
      end % thread
      Port
   end % fun StartPlayer

   /**
    * Bind the ID of the player.
    * 
    * @param ?RetID: unbound, set to ID by function.
    */
   fun {GetId ?RetID}
      RetID = ID
      true
   end % fun GetId

   /**
    * Bind the ID and State of the player.
    *
    * @param     State: state of the player.
    * @param    ?RetID: unbound, set to ID by function.
    * @param ?RetState: unbound, set to State by function.
    */
   fun {GetState State ?RetID ?RetState}
      RetID = ID
      RetState = State
      true
   end % fun GetState

   /**
    * Assign a spawn position.
    * 
    * @param SpPos: Spawn position of the current player.
    */
   fun {AssignSpawn SpPos}
      if {Value.isDet SpawnPos} then
         raise('Spawn position already set in AssignSpawn.') end
         false
      else
         SpawnPos = SpPos
         true
      end % if
   end % fun AssignSpawn

   /**
    * Spawn the player in its assigned position if possible, i.e.:
    *  - the player has lives left;
    *  - the player is not already on the board.
    * If any of these conditions are not met, then null is returned for both the ID and Pos.
    *
    * @param   State: state of the player.
    * @param   Lives: number of lives of the player.
    * @param  ?RetID: unbound, set to ID (or null) by function.
    * @param ?RetPos: unbound, set to SpawnPos (or null) by function.
    */
   fun {SpawnF State Lives ?RetID ?RetSpawn}
      if State == on then
         RetID = null
         RetSpawn = null
         raise('Tried spawning a player that was already on the board in SpawnF.') end
         false
      elseif Lives =< 0 then
         RetID = null
         RetSpawn = null
         raise('No more lives left in SpawnF.') end
         false
      else
         RetID = ID
         RetSpawn = SpawnPos
         true
      end % if
   end % fun SpawnF

   /**
    * Determine what action the player should perform.
    * 
    * @param      State: state of the player.
    * @param        Pos: position of the player.
    * @param      Bombs: number of bombs of the player.
    * @param        Map: map of the game.
    * @param     ?RetID: unbound, set to ID (or null) by function.
    * @param ?RetAction: unbound, set to the action the player should perform (or null) by function.
    * @param    ?NewPos: unbound, new position of the player.
    * @param  ?NewBombs: unbound, new number of bombs of the player.
    */
   fun {DoAction State Pos Bombs Map ?RetID ?RetAction ?NewPos ?NewBombs}
      if State == off then
         RetID = null
         RetAction = null
         NewPos = Pos
         NewBombs = Bombs
         raise('Off-board player tried to perform an action in DoAction.') end
         false
      elseif Bombs > 0 andthen {OS.rand} mod 10 > 8 then
         local CircularNext MoveDir Available Pick in
            /**
            * Determine whether a given move is legal.
            *
            * @param Dir: queried direction.
            */
            fun {MoveDir Dir}
               if Dir == xplus andthen {Nth {Nth Map Pos.y} Pos.x+1} == 1 then ok
               elseif Dir == xminus andthen {Nth {Nth Map Pos.y} Pos.x-1} == 1 then ok
               elseif Dir == yplus andthen {Nth {Nth Map Pos.y+1} Pos.x} == 1 then ok
               elseif Dir == yminus andthen {Nth {Nth Map Pos.y-1} Pos.x} == 1 then ok
               else ko
               end % if
            end % fun MoveDir
            Available = {MoveDir xplus}|{MoveDir xminus}|{MoveDir yplus}|{MoveDir yminus}
            
            Pick = {OS.rand} mod 4 + 1
            /**
            * Move in a list of ok and ko until ok is found, circularly, from a given starting value.
            *
            * @param L: list with ok and ko.
            * @param N: starting value.
            */
            fun {CircularNext L N}
               case {List.drop L N-1}
               of ok|T then N
               [] ko|nil then
                  {CircularNext L 1}
               [] ko|T then
                  {CircularNext L N+1}
               end % case
            end % fun CircularNext

            % Randomly decide which way to move, among available directions.
            case {CircularNext Available Pick} 
            of 1 then NewPos = pt(x:Pos.x+1 y:Pos.y)
            [] 2 then NewPos = pt(x:Pos.x-1 y:Pos.y)
            [] 3 then NewPos = pt(x:Pos.x y:Pos.y+1)
            [] 4 then NewPos = pt(x:Pos.x y:Pos.y-1)
            end % case

            RetID = ID
            RetAction = move(NewPos)
            NewBombs = Bombs
            true
         end % local
      else
         RetID = ID
         RetAction = bomb(Pos)
         NewPos = Pos
         NewBombs = Bombs - 1
         true
      end % if
   end % fun DoAction

   /**
    * Add an item to the player.
    *
    * @param      State: state of the player.
    * @param      Bombs: the number of bombs of the player.
    * @param      Score: the score of the player.
    * @param       Type: the type of the item.
    * @param     Option: the value of the item.
    * @param ?RetResult: unobund, new value of the counter.
    * @param  ?NewBombs: unbound, new number of bombs of the player.
    * @param  ?NewScore: unbound, new score of the player.
    */
   fun {Add State Bombs Score Type Option ?RetResult ?NewBombs ?NewScore}
      if State == off then
         RetResult = 69
         NewBombs = Bombs
         NewScore = Score
         raise('Tried adding item to off-board player in Add.') end
         false
      else
         case Type
         of bomb then
            NewBombs = Bombs + Option
            NewScore = Score
            RetResult = NewBombs
            true
         [] point then
            NewScore = Score + 1
            NewBombs = Bombs
            RetResult = NewScore
            true
         else
            RetResult = 69
            NewBombs = Bombs
            NewScore = Score
            raise('Unknown type in Add.') end
            false
         end % case Type
      end % if
   end % fun Add

   /**
    * Handle getting hit by fire.
    * 
    * @param      State: state of the player.
    * @param      Lives: number of lives of the player
    * @param     ?RetID: unbound, <bomber> ID of the player.
    * @param ?RetResult: unbound, result of getting hit.
    * @param  ?NewState: unbound, new state of the player.
    * @param  ?NewLives: unbound, new number of lives of the player.
    */
   fun {GotHit State Lives ?RetID ?RetResult ?NewState ?NewLives}
      if State == off then
         RetID = null
         RetResult = off
         NewState = State
         NewLives = Lives
         raise('Off-board player received gotHit message in GotHit.') end
         false
      elseif Lives =< 0 then
         RetID = null
         RetResult = off
         NewState = State
         NewLives = Lives
         raise('Dead player received gotHit message in GotHit.') end
         false
      else
         RetID = ID
         NewState = off
         NewLives = Lives - 1
         RetResult = death(NewLives)
         true
      end % if
   end % fun GotHit

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
            raise('Error in NewColumns function: Map != H|T.') end
         end % case Map
      end % fun NewColumns
   in
      % Works if 1 < X, Y < N, 1 and N being the borders.
      if X =< 1 orelse Y =< 1 orelse Y >= Input.nbRow orelse X >= Input.nbColumn then
         raise('Assertion error in BuildNewMap function') end
      end % if
      {NewColumns Map X Y 1}
   end % fun UpdateMap

   /**
    * Handle informational messages.
    *
    * @param     Map: map of the game.
    * @param Message: informational message being handled.
    * @param ?NewMap: unbound, new map of the game.
    */
   fun {Info Map Message ?NewMap}
      case Message
      of spawnPlayer(ID SPPos) then
         true
      [] movePlayer(ID MPPos) then
         true
      [] deadPlayer(ID) then
         true
      [] bombPlanted(BPPos) then
         true
      [] bombExploded(BEPos) then
         true
      [] boxRemoved(BRPos) then
         NewMap = {UpdateMap Map BRPos.x BRPos.y 1}
         true
      end % case Message
   end % fun Info

   /**
    * Read the current stream to determine actions.
    *
    * @param Stream: input stream of bomber messages.
    * @param  State: state of the player.
    * @param  Lives: number of lives of the player.
    * @param    Pos: position of the player.
    * @param  Bombs: number of bombs of the player.
    * @param    Map: map of the game.
    * @param  Score: score of the player.
    */
   proc {TreatStream Stream State Lives Pos Bombs Map Score}
      case Stream
      of nil then skip
      [] getId(RetID)|S then
         if {GetId RetID} then
            {TreatStream S State Lives Pos Bombs Map Score}
         else
            skip
         end % if
      [] getState(RetID RetState)|S then
         if {GetState State RetID RetState} then
            {TreatStream S State Lives Pos Bombs Map Score}
         else
            skip
         end % if
      [] assignSpawn(SpPos)|S then
         if {AssignSpawn SpPos} then
            {TreatStream S State Lives Pos Bombs Map Score}
         else
            skip
         end % if
      [] spawn(RetID RetPos)|S then
         if {SpawnF State Lives RetID RetPos} then
            {TreatStream S on Lives SpawnPos Bombs Map Score}
         else
            skip
         end % if
      [] doaction(RetID RetAction)|S then
         local NewPos NewBombs in
            if {DoAction State Pos Bombs Map RetID RetAction NewPos NewBombs} then
               {TreatStream S State Lives NewPos NewBombs Map Score}
            else
               skip
            end % if
         end % local
      [] add(Type Option RetResult)|S then
         local NewBombs NewScore in
            if {Add State Bombs Score Type Option RetResult NewBombs NewScore} then
               {TreatStream S State Lives Pos NewBombs Map NewScore}
            else
               skip
            end % if
         end % local
      [] gotHit(RetID RetResult)|S then
         local NewState NewLives in
            if {GotHit State Lives RetID RetResult NewState NewLives} then
               {TreatStream S NewState NewLives Pos Bombs Map Score}
            else
               skip
            end % if
         end % local
      [] info(Message)|S then
         local NewMap in
            if {Info Map Message NewMap} then
               {TreatStream S State Lives Pos Bombs NewMap Score}
            else
               skip
            end % local 
         end % if
      else
         skip
      end % case Stream
   end % proc TreatStream
end % functor
