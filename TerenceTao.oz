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
   SetNth

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
         {TreatStream OutputStream summary(state:off lives:Input.nbLives pos:null bombs:Input.nbBombs map:Input.Map score:0)}
      end % thread
      Port
   end % fun StartPlayer


   /**
    * Set the nth value of a list to a given value
    *
    * @param  Xs: list.
    * @param   N: index of the value that should be changed.
    * @oaram Val: new value of the chnaged element.
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
    * Bind the ID of the player.
    * 
    * @param Summary: summary of the game.
    * @param  ?RetID: unbound, set to ID by function.
    */
   fun {GetId Summary ?RetID}
      RetID = ID
      Summary
   end % fun GetId

   /**
    * Bind the ID and State of the player.
    *
    * @param   Summary: summary of the game.
    * @param    ?RetID: unbound, set to ID by function.
    * @param ?RetState: unbound, set to State by function.
    */
   fun {GetState Summary ?RetID ?RetState}
      RetID = ID
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
      if {Value.isDet SpawnPos} then
         raise('Spawn position already set in AssignSpawn.') end
      else
         SpawnPos = SpPos
      end % if
      Summary
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
   fun {SpawnF Summary ?RetID ?RetSpawn}
      if Summary.state == on then
         RetID = null
         RetSpawn = null
         raise('Tried spawning a player that was already on the board in SpawnF.') end
      elseif Summary.lives =< 0 then
         RetID = null
         RetSpawn = null
         raise('No more lives left in SpawnF.') end
      else
         RetID = ID
         RetSpawn = SpawnPos
      end % if
      Summary
   end % fun SpawnF

   /**
    * Determine what action the player should perform.
    * 
    * @param    Summary: summary of the game.
    * @param     ?RetID: unbound, set to ID (or null) by function.
    * @param ?RetAction: unbound, set to the action the player should perform (or null) by function.
    */
   fun {DoAction Summary ?RetID ?RetAction}
      if Summary.state == off then
         RetID = null
         RetAction = null
         raise('Off-board player tried to perform an action in DoAction.') end
         Summary
      elseif Summary.bombs > 0 andthen {OS.rand} mod 10 > 8 then
         local CircularNext MoveDir Available Pick NewPos in
            /**
            * Determine whether a given move is legal.
            *
            * @param Dir: queried direction.
            */
            fun {MoveDir Dir}
               if Dir == xplus andthen {Nth {Nth Summary.map Summary.pos.y} Summary.pos.x+1} == 1 then ok
               elseif Dir == xminus andthen {Nth {Nth Summary.map Summary.pos.y} Summary.pos.x-1} == 1 then ok
               elseif Dir == yplus andthen {Nth {Nth Summary.map Summary.pos.y+1} Summary.pos.x} == 1 then ok
               elseif Dir == yminus andthen {Nth {Nth Summary.map Summary.pos.y-1} Summary.pos.x} == 1 then ok
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
            of 1 then NewPos = pt(x:Summary.pos.x+1 y:Summary.pos.y)
            [] 2 then NewPos = pt(x:Summary.pos.x-1 y:Summary.pos.y)
            [] 3 then NewPos = pt(x:Summary.pos.x y:Summary.pos.y+1)
            [] 4 then NewPos = pt(x:Summary.pos.x y:Summary.pos.y-1)
            end % case

            RetID = ID
            RetAction = move(NewPos)
            summary(state:Summary.state lives:Summary.lives pos:NewPos bombs:Summary.bombs map:Summary.map score:Summary.score)
         end % local
      else
         RetID = ID
         RetAction = bomb(Summary.pos)
         summary(state:Summary.state lives:Summary.lives pos:Summary.pos bombs:Summary.bombs-1 map:Summary.map score:Summary.score)
      end % if
   end % fun DoAction

   /**
    * Add an item to the player.
    *
    * @param    Summary: summary of the game.
    * @param       Type: the type of the item.
    * @param     Option: the value of the item.
    * @param ?RetResult: unobund, new value of the counter.
    */
   fun {Add Summary Type Option ?RetResult}
      if Summary.state == off then
         RetResult = 69
         raise('Tried adding item to off-board player in Add.') end
         Summary
      else
         case Type
         of bomb then
            RetResult = Summary.bombs + Option
            summary(state:Summary.state lives:Summary.lives pos:Summary.pos bombs:Summary.bombs+Option map:Summary.map score:Summary.score)
         [] point then
            RetResult = Summary.score+1
            summary(state:Summary.state lives:Summary.lives pos:Summary.pos bombs:Summary.bombs map:Summary.map score:Summary.score+1)
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
   fun {GotHit Summary ?RetID ?RetResult}
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
      else
         RetID = ID
         RetResult = death(Summary.lives-1)
         summary(state:off lives:Summary.lives-1 pos:Summary.pos bombs:Summary.bombs map:Summary.map score:Summary.score)
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
         Summary
      [] bombExploded(BEPos) then
         Summary
      [] boxRemoved(BRPos) then
         summary(state:Summary.state lives:Summary.lives pos:Summary.pos bombs:Summary.bombs map:{UpdateMap Map BRPos.x BRPos.y 1} score:Summary.score)
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