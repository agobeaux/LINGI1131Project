functor
import
   GUI
   Input
   PlayerManager
   Browser
   System % System.show
   OS % OS.rand
define
   PGUI
   PPlayers
   fun {CreatePlayers N Colors Names}
      if N == 0 then nil
      else
         case Colors#Names of (Color|T1)#(Name|T2) then Bomber in
            Bomber = bomber(id:N color:Color name:Name)
            {Send PGUI initPlayer(Bomber)}
            {PlayerManager.playerGenerator player000bomber Bomber}|{CreatePlayers N-1 T1 T2}
         else nil
         end
      end
   end

   /*
   % Intéressant pour générer des spawns aléatoires. Ennuyant pour ne pas avoir deux fois le même spawn
   proc {SpawnMapRand Map PPlayers}
      
      fun {ProcessElt IdSquare X Y}
         case IdSquare
         of 2 then {Send PGUI spawnPoint(pt(x:X y:Y))} nil
         [] 3 then {Send PGUI spawnBonus(pt(x:X y:Y))} nil
         [] 4 then pt(x:X y:Y)|nil 
         else nil end % wall / empty : rien à faire
      end
      fun {SpawnRow Row X Y}
         case Row
         of H|T then Z W in
            Z = {ProcessElt H X Y}
            W = {SpawnRow T X+1 Y}
            {Append Z W}
         [] nil then nil
         end
      end
      fun {SpawnEntire Col Y} % function so that we pick a spawn randomly
         case Col
         of H|T then Z in
            Z = {SpawnRow H 1 Y}
            {Append Z {SpawnEntire T Y+1}}
         [] nil then nil
         end
      end
      Spawns
   in
      Spawns = {SpawnEntire Map 1}
      for I in 1..Input.nbBombers do
         {System.show {OS.rand}}
      end
      
   end
   */
   proc {SpawnMap Map PPlayers}
      
      fun {ProcessElt IdSquare X Y}
         case IdSquare
         of 2 then {Send PGUI spawnPoint(pt(x:X y:Y))} nil
         [] 3 then {Send PGUI spawnBonus(pt(x:X y:Y))} nil
         [] 4 then pt(x:X y:Y)|nil 
         else nil end % wall / empty : rien à faire
      end
      fun {SpawnRow Row X Y}
         case Row
         of H|T then Z W in
            Z = {ProcessElt H X Y}
            W = {SpawnRow T X+1 Y}
            {Append Z W}
         [] nil then nil
         end
      end
      fun {SpawnEntire Col Y}
         case Col
         of H|T then Z in
            Z = {SpawnRow H 1 Y}
            {Append Z {SpawnEntire T Y+1}}
         [] nil then nil
         end
      end
      Spawns
      proc{SpawnPlayers N PPlayers SpawnList}
         if N == 0 then skip
         else
            case PPlayers#SpawnList of (Play|T1)#(Spawn|T2) then ID Pos RealID in
               {Send Play assignSpawn(Spawn)}
               {Send Play spawn(ID Pos)}
               {Send Play getId(RealID)}
               if {Or ID \= RealID  Pos \= Spawn} then {System.show ID#N} raise('Error, Player spawned at wrong place') end end
               {Send PGUI spawnPlayer(ID Pos)}
               {SpawnPlayers N-1 T1 T2}
            end
         end
      end
   in
      Spawns = {SpawnEntire Map 1}
      {SpawnPlayers Input.nbBombers PPlayers Spawns}
      
   end

   proc {SendMoveInfo PPlayersList Info}
      case PPlayersList of PortP|T then ID in
         Info = movePlayer(ID _)
         if ID \= ID.id then {Send PortP info(Info)} end
         {SendMoveInfo T Info}
      [] nil then skip
      else raise('Error in SendMoveInfo') end
      end
   end
   proc {SendBombInfo PPlayersList Info}
      case PPlayersList of PortP|T then 
         {Send PortP info(Info)} % TODO : renvoie à celui qui a posé la bombe => à corriger
         {SendBombInfo T Info}
      [] nil then skip
      else raise('Error in SendBombInfo') end
      end
   end
   proc {SendBoxInfo PPlayersList Info}
      case PPlayersList of PortP|T then 
         {Send PortP info(Info)}
         {SendBoxInfo T Info}
      [] nil then skip
      else raise('Error in SendBoxInfo') end
      end
   end
   proc {SendBombExplodedInfo PPlayersList Info}
      case PPlayersList of PortP|T then 
         {Send PortP info(Info)}
         {SendBombExplodedInfo T Info}
      [] nil then skip
      else raise('Error in SendBombExplodedInfo') end
      end
   end
   
   proc {ExplodeBomb Pos PortPlayer}
      proc {ProcessExplode X Y}
         {System.show 'Im in ProcessExplode !!!!!!!!!!!!!'} % TODO : delete
         local Pos2 in
            Pos2 = pt(x:X y:Y)
            case {Nth {Nth Input.map Y} X}
            of 2 then {Send PGUI hideBox(Pos2)} {SendBoxInfo PPlayers boxRemoved(Pos2)} {Send PGUI spawnFire(Pos2)}
            [] 3 then {Send PGUI hideBonus(Pos2)} {Send PGUI spawnFire(Pos2)}
            [] 1 then skip % wall
            else {Send PGUI spawnFire(Pos2)}
            end
         end
      end
   in
      {System.show 'Im in ExplodeBomb'} % TODO : delete
      {Send PGUI hideBomb(Pos)}
      {Send PortPlayer add(bomb 1 _)}
      {SendBombExplodedInfo PPlayers bombExploded(Pos)}
      case Pos of pt(x:X y:Y) then I in
         for I in 1..Input.fire do
            if X-I > 0 then
               {ProcessExplode X-I Y}
            end
            if X+I =< Input.nbColumn then
               {ProcessExplode X+I Y}
            end
            if Y-I > 0 then
               {ProcessExplode X Y-I}
            end
            if Y+I =< Input.nbColumn then
               {ProcessExplode X Y+I}
            end
         end
      else raise('Problem in function ExplodeBomb') end
      end
   end
            
   
   fun {ProcessBombs BombsList NbTurn}
      {System.show NbTurn}
      if {Not {Value.isDet BombsList}} then
         {System.show 'ProcessBombs not isDet'}
         BombsList
      else
         case BombsList
         of bomb(turn:Turn pos:Pos port:PortPlayer)|T then
            {System.show 'in case bomb'}
            if(Turn == NbTurn) then
               {ExplodeBomb Pos PortPlayer}
               {ProcessBombs T NbTurn}
            else BombsList end
         [] H|T then raise('Problem in function ProcessBombs case H|T') end
         else raise('Problem in function ProcessBombs else') end
         end
      end
   end
   
   proc {RunTurnByTurn}
      BombPort
      proc {RunTurn N NbAlive PPlays BombsList NbTurn}
         if NbAlive =< 1 then skip end
         if N == 0 then {RunTurn Input.nbBombers NbAlive PPlayers BombsList NbTurn} end % TODO : change nil
         local W Z in
            Z = {ProcessBombs BombsList NbTurn}

            case PPlays of PPlay|T then ID State Action in
               {Send PPlay getState(ID State)}
               if State == off then {RunTurn N-1 NbAlive T BombsList NbTurn+1} end % TODO : change nil
               {Send PPlay doaction(_ Action)}
               case Action
               of move(Pos) then
                  {Send PGUI movePlayer(ID Pos)}
                  {SendMoveInfo PPlayers movePlayer(ID Pos)}
                  W = Z
               [] bomb(Pos) then
                  {Send PGUI spawnBomb(Pos)} % TODO : Pos ou ID Pos ? Juste Pos serait logique. Mais avec ID logique pour donner des points s'il kill qqn
                  {SendBombInfo PPlayers bombPlanted(Pos)} % TODO : Garder les bombes en mémoire pour savoir quand les exploser
                  {Send BombPort bomb(turn:NbTurn+Input.timingBomb*Input.nbBombers pos:Pos port:PPlay)}
               else raise('Unrecognised msg in function Main.RunTurn') end
               end
               {Delay 2000}
               {System.show Z}
               {RunTurn N-1 NbAlive T Z NbTurn+1} % TODO CHANGE NIL
            else raise('Problem in function Main.RunTurn') end
            end
         end
      end
      BombsL
   in
      BombPort = {NewPort BombsL}
      {RunTurn Input.nbBombers Input.nbBombers PPlayers BombsL 1} % TODO : modify nil
   end

in
   %% Implement your controller here

   % Create the port for the GUI and initialise it
   PGUI = {GUI.portWindow}
   {Send PGUI buildWindow}
   

   % Create the ports for the players using the PlayerManager and assign its unique ID.
   PPlayers = {CreatePlayers Input.nbBombers Input.colorsBombers Input.bombers}

   % Spawn bonuses, boxes and players
   {SpawnMap Input.map PPlayers}
   
   {Delay 5000} % à modifier

   if Input.isTurnByTurn then
      {RunTurnByTurn} % TODO un thread ?
   end
   % TODO : else : RunSimul


end
