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
   Name = 'Debug001kardashian'

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
         {TreatStream OutputStream summary(state:off id:ID lives:Input.nbLives pos:null sppos:nil bombs:Input.nbBombs map:Input.map score:0)}
      end % thread
      Port
   end % fun StartPlayer

   /**
    * Bind the ID of the player.
    * 
    * @param Summary: summary of the game.
    * @param  ?RetID: unbound, set to ID by function.
    */
   fun {GetId Summary ?RetID}
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
   fun {GetState Summary ?RetID ?RetState}
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
   fun {SpawnF Summary ?RetID ?RetSpawn}
      if Summary.state == on then
         RetID = null
         RetSpawn = null
         Summary
      elseif Summary.lives =< 0 then
         RetID = null
         RetSpawn = null
         Summary
      else
         RetID = Summary.id
         RetSpawn = Summary.sppos
         {AdjoinList Summary [state#on pos#RetSpawn score#0]}
      end % if
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
      elseif Summary.bombs =< 0 orelse {OS.rand} mod 10 < 9 then
         local CircularNext MoveDir Available Pick NewPos in
            /**
            * Determine whether a given move is legal.
            *
            * @param Dir: queried direction.
            */
            fun {MoveDir Dir}
               if Dir == xplus andthen {Nth {Nth Summary.map Summary.pos.y} Summary.pos.x+1} mod 4 == 0 then ok
               elseif Dir == xminus andthen {Nth {Nth Summary.map Summary.pos.y} Summary.pos.x-1} mod 4 == 0 then ok
               elseif Dir == yplus andthen {Nth {Nth Summary.map Summary.pos.y+1} Summary.pos.x} mod 4 == 0 then ok
               elseif Dir == yminus andthen {Nth {Nth Summary.map Summary.pos.y-1} Summary.pos.x} mod 4 == 0 then ok
               else ko
               end % if
            end % fun MoveDir
            Available = {MoveDir xplus}|{MoveDir xminus}|{MoveDir yplus}|{MoveDir yminus}|nil
            
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

            RetID = Summary.id
            RetAction = move(NewPos)
            {System.show 'Hmmmm'}
            {AdjoinList Summary [pos#NewPos]}
         end % local
      else
         RetID = Summary.id
         RetAction = bomb(Summary.pos)
         {System.show 'Hmmmm2'}
         {AdjoinList Summary [bombs#Summary.bombs-1]}
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
            {AdjoinList Summary [bombs#Summary.bombs+Option]}
         [] point then
            RetResult = Summary.score+1
            {AdjoinList Summary [score#Summary.score+1]}
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
         RetID = Summary.id
         RetResult = death(Summary.lives-1)
         {AdjoinList Summary [state#off lives#Summary.lives-1]}
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
         {AdjoinList Summary [map#{UpdateMap Summary.map BRPos.x BRPos.y 0}]}
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
