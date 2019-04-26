functor
import
   GUI
   Input
   PlayerManager
   Browser
   System % System.show
   OS % OS.rand
export
   processMove : ProcessMove % c'était pour le test. TODO : remove ?
define
   PGUI
   PPlayers
   PScore
   ScoreStream
   fun {CreatePlayers N Colors Names}
      if N == 0 then nil
      else
         case Colors#Names of (Color|T1)#(Name|T2) then Bomber in
            Bomber = bomber(id:N color:Color name:Name)
            {Send PGUI initPlayer(Bomber)}
            {Send PScore 0}
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
         of 4 then pt(x:X y:Y)|nil % spawn
         % other cases not needed since points and bonuses should spawn only when boxes get destroyed
         %[] 2 then {Send PGUI spawnPoint(pt(x:X y:Y))} nil
         %[] 3 then {Send PGUI spawnBonus(pt(x:X y:Y))} nil
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
            case PPlayers#SpawnList of (PPlay|T1)#(Spawn|T2) then ID Pos RealID in
               {Send PPlay assignSpawn(Spawn)}
               {Send PPlay spawn(ID Pos)}
               {Send PPlay getId(RealID)}
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
   
   fun {ExplodeBomb Pos PortPlayer HideFPort Map LastEndChangeList}
      % TODO TRES IMPORTANT : quand y'aura des explosions qui se croisent il faudra bien le gérer... On devra changer la map après tout et pas directement après
      % car sinon un feu pourrait aller plus loin qu'une boîte. => stream avec les endroits à mettre en feu
      fun {ProcessExplode X Y ChangeRecord} % TODO : WARNING : simultaneous il faudra le même map pour tous les joueurs
         {System.show 'Im in ProcessExplode !!!!!!!!!!!!!'} % TODO : delete
         local Pos2 in
            Pos2 = pt(x:X y:Y)
            case {Nth {Nth Map Y} X}
            of 2 then % point box
               {Send PGUI hideBox(Pos2)} {SendBoxInfo PPlayers boxRemoved(Pos2)} {Send PGUI spawnPoint(Pos2)} {Send PGUI spawnFire(Pos2)} ChangeRecord = X#Y#5 {Send HideFPort hideFire(Pos2)} false
            [] 3 then % bonus box
               {Send PGUI hideBox(Pos2)} {SendBoxInfo PPlayers boxRemoved(Pos2)} {Send PGUI spawnBonus(Pos2)} {Send PGUI spawnFire(Pos2)} ChangeRecord = X#Y#6 {Send HideFPort hideFire(Pos2)} false
            [] 1 then false % wall
            else {Send PGUI spawnFire(Pos2)} {Send HideFPort hideFire(Pos2)} true % TODO WARNING : attention si on rajoute des éléments le 'else' sera insuffisant...
            end
         end
      end
      proc {ProcessExplodeXM X Y Dx ChangeRecord}
         if {And Dx =< Input.fire X-Dx>0} then X2 DoNext in
            X2 = X - Dx
            DoNext = {ProcessExplode X2 Y ChangeRecord}
            if DoNext then {ProcessExplodeXM X Y Dx+1 ChangeRecord} end
         end
      end
      proc {ProcessExplodeXP X Y Dx ChangeRecord}
         if {And Dx =< Input.fire X+Dx < Input.nbColumn} then X2 DoNext in
            X2 = X + Dx
            DoNext = {ProcessExplode X2 Y ChangeRecord}
            if DoNext then {ProcessExplodeXP X Y Dx+1 ChangeRecord} end
         end
      end
      proc {ProcessExplodeYM X Y Dy ChangeRecord}
         if {And Dy =< Input.fire Y-Dy > 0} then Y2 DoNext in
            Y2 = Y - Dy
            DoNext = {ProcessExplode X Y2 ChangeRecord}
            if DoNext then {ProcessExplodeYM X Y Dy+1 ChangeRecord} end
         end
      end
      proc {ProcessExplodeYP X Y Dy ChangeRecord}
         if {And Dy =< Input.fire Y+Dy < Input.nbRow} then Y2 DoNext in
            Y2 = Y + Dy
            DoNext = {ProcessExplode X Y2 ChangeRecord}
            if DoNext then {ProcessExplodeYP X Y Dy+1 ChangeRecord} end
         end
      end
   in
      {System.show 'Im in ExplodeBomb'} % TODO : delete
      {Send PGUI hideBomb(Pos)}
      {Send PortPlayer add(bomb 1 _)}
      {SendBombExplodedInfo PPlayers bombExploded(Pos)}
      case Pos of pt(x:X y:Y) then NewEndChangeList List2 List3 List4 ChangeRecord1 ChangeRecord2 ChangeRecord3 ChangeRecord4 in
         {Send PGUI spawnFire(Pos)} % Fire where bomb explodes
         {Send HideFPort hideFire(Pos)} % Make it disappear during the next turn

         {ProcessExplodeXM X Y 1 ChangeRecord1}
         if {Value.isDet ChangeRecord1} then LastEndChangeList = ChangeRecord1|List2
         else LastEndChangeList = List2 end

         {ProcessExplodeXP X Y 1 ChangeRecord2}
         if {Value.isDet ChangeRecord2} then List2 = ChangeRecord2|List3
         else List2 = List3 end

         {ProcessExplodeYM X Y 1 ChangeRecord3}
         if {Value.isDet ChangeRecord3} then List3 = ChangeRecord3|List4
         else List3 = List4 end

         {ProcessExplodeYP X Y 1 ChangeRecord4}
         if {Value.isDet ChangeRecord4} then List4 = ChangeRecord4|NewEndChangeList
         else List4 = NewEndChangeList end

         thread {System.show 'LastEndChangeList'#LastEndChangeList} end
         thread {System.show 'NewEndChangeList'#NewEndChangeList} end

         NewEndChangeList % returns the new unbound end of ChangeList so that we can append lists of changes from other
         % bombs exploding during the same turn (debugs border case when 2 bombs want to explode the same box : fire doesn't go further for any of the bombs)

      else raise('Problem in function ExplodeBomb') end
      end
   end
            
   
   fun {ProcessBombs BombsList NbTurn HideFPort Map NewMap ChangeList EndChangeList}
      {System.show 'inProcessBombs'}
      {System.show NbTurn} % TODO : delete
      if {Not {Value.isDet BombsList}} then
         {System.show 'ProcessBombs not isDet'}
         EndChangeList = nil % finally ends the list
         thread {System.show 'ChangeList'#ChangeList} end
         NewMap = {BuildNewMapList Map ChangeList}
         {System.show 'NewMap built in ProcessBombs not isDet'}
         BombsList
      else
         case BombsList
         of bomb(turn:Turn pos:Pos port:PortPlayer)|T then
            {System.show 'in case bomb ProcessBombs'} % TODO : delete
            thread
               {System.show 'checking if ChangeList == EndChangeList :'}
               {System.show ChangeList==EndChangeList}
            end
            if(Turn == NbTurn) then NewEnd in
               {System.show 'in if ProcessBombs'}
               NewEnd = {ExplodeBomb Pos PortPlayer HideFPort Map EndChangeList}
               thread {System.show 'ChangeList # EndChangeList # NewEnd'#ChangeList#EndChangeList#NewEnd} end
               {ProcessBombs T NbTurn HideFPort Map NewMap ChangeList NewEnd}
            else
               {System.show 'in else ProcessBombs'}
               EndChangeList = nil % finally ends the list
               NewMap = {BuildNewMapList Map ChangeList}
               BombsList
            end
         [] H|T then raise('Problem in function ProcessBombs case H|T') end
         else raise('Problem in function ProcessBombs else') end
         end
      end
   end
   
   
   fun {ProcessHideF FireStream}
      {System.show 'inProcessHideF'}
      if {Not {Value.isDet FireStream}} then
         {System.show 'ProcessHideF not isDet'}
         FireStream
      else
         case FireStream
         of hideFire(Pos)|T then
            {Send PGUI hideFire(Pos)}
            {ProcessHideF T}
         [] H|T then raise('Problem in function ProcessHideF case H|T') end
         else raise('Problem in function ProcessHideF else') end
         end
      end
   end
   
   proc {ProcessBonus PPlay PScore Score}
      RandomValue
   in
      RandomValue = {OS.rand} mod 2
      case RandomValue
      of 0 then
         {Send PPlay add(bomb 1)}
         {Send PScore Score}
      [] 1 then ID in
         {Send PPlay add(point 10)}
         {Send PScore Score+10}
         {Send PPlay getId(ID)}
         {Send PGUI scoreUpdate(ID Score+10)}
      end
   end

   % TODO : en simultané, ils pourront être en même temps sur une case BONUS : à gérer : +le total pour chacun ? + la moitié ? Random give ? give au premier dans notre liste (unfair) ?

   fun {BuildNewMapList Map List}
      if {Value.isFree List} then {System.show 'UNBOUND LIST !!! BuildNewMapList'} end % TODO : delete
      case List
      of (X#Y#Value)|T then {BuildNewMapList {BuildNewMap Map X Y Value} T}
      [] nil then {System.show 'Leaving BuildNewMapList'} Map % TODO : delete show
      else raise('Error in BuildNewMapList : list pattern not recognized') end
      end
   end

   fun {BuildNewMap Map X Y Value}
      fun {NewRow Row X ThisX}
         {System.show 'in NewRow'}
         case Row of H|T then
            if X == ThisX then Value|T % change into Value given
            else H|{NewRow T X ThisX+1}
            end
         else raise('Error in NewRow function : Row != H|T') end
         end
      end
      fun {NewColumns Map X Y ThisY}
         {System.show 'in NewColumns'}
         case Map of H|T then
            if ThisY == Y then % column which should change
               {NewRow H X 1}|T
            else H|{NewColumns T X Y ThisY+1}
            end
         else raise('Error in NewColumns function : Map != H|T') end
         end
      end
   in
      % works if 1 < X,Y < N. 1 and N being the borders
      if {Or X =< 1 {Or Y =< 1 {Or Y >= Input.nbRow X >= Input.nbColumn}}} then
         raise('Assertion error in BuildNewMap function') end
      end
      {NewColumns Map X Y 1}
   end

   fun {ProcessMove PPlay Pos Map Score}
      {System.show 'in ProcessMove function'}
      % similar solution : construct the map at the same time as checking
      case Pos of pt(x:X y:Y) then Value in
         Value = {Nth {Nth Map Y} X}
         {System.show 'Map : '}
         {System.show Map}
         {Wait {Nth {Nth Map Input.nbRow} Input.nbColumn}}
         {System.show 'Value in ProcessMove function : '}
         {System.show Value}
         case Value
         of 0 then % Simple floor
            {Send PScore Score}
            Map
         [] 1 then raise('Problem in ProcessMove function, moved into a wall !') end
         [] 2 then raise('Problem in ProcessMove function, moved into a point box !') end
         [] 3 then raise('Problem in ProcessMove function, moved into a bonus box !') end
         [] 4 then % Floor with spawn
            {Send PScore Score}
            Map
         [] 5 then NewMap ID in % point
            {Send PPlay add(point 1)}
            {Send PScore Score+1}
            {Send PPlay getId(ID)}
            {Send PGUI scoreUpdate(ID Score+1)}
            {Send PGUI hidePoint(Pos)}
            % make this tile a floor :
            NewMap = {BuildNewMap Map X Y 0} % change tile into simple floor
            {System.show 'ProcessMove : case Value == 5, map : '}
            {System.show NewMap}
            NewMap
         [] 6 then Z NewMap in % bonus
            % TODO : ProcessBonus (and send sth to the player)
            {Send PGUI hideBonus(Pos)}
            NewMap = {BuildNewMap Map X Y 0} % change tile into simple floor
            {ProcessBonus PPlay PScore Score}
            {System.show 'ProcessMove : case Value == 6, map : '}
            {System.show NewMap}
            NewMap
         else raise('Problem in ProcessMove function, map with unknown value') end
         end
      else raise('Error in function ProcessMove, wrong Pos pattern') end
      end
   end
   
   proc {RunTurnByTurn}
      BombPort
      proc {RunTurn N NbAlive PPlays BombsList NbTurn HideFireStream Map ScoreStream}
         if NbAlive =< 1 then skip end
         if N == 0 then {RunTurn Input.nbBombers NbAlive PPlayers BombsList NbTurn HideFireStream Map ScoreStream}
         else
            
            local NewBombsList NewHideFireStream NMapProcessBombs in
               NewHideFireStream = {ProcessHideF HideFireStream}
               {System.show 'After NewBombsList'}
               case PPlays#ScoreStream of (PPlay|T)#(Score|TStream) then ID State Action NewMap in
                  {Send PPlay getState(ID State)}
                  if State == off then ChangeList in % Problem : have to send score to keep ordering
                     {Send PScore Score}
                     NewBombsList = {ProcessBombs BombsList NbTurn HideFPort Map NMapProcessBombs ChangeList ChangeList} % check function to understand the 2x ChangeList
                     {RunTurn N-1 NbAlive T BombsList NbTurn+1 NewHideFireStream NMapProcessBombs TStream}
                  else ChangeList in
                     {Send PPlay doaction(_ Action)}
                     case Action
                     of move(Pos) then
                        {System.show 'move(Pos) : '}
                        {System.show Pos}
                        NewMap = {ProcessMove PPlay Pos Map Score}
                        {System.show 'After NewMap = ProcessMove call'}
                        {Send PGUI movePlayer(ID Pos)}
                        {SendMoveInfo PPlayers movePlayer(ID Pos)}
                     [] bomb(Pos) then
                        {Send PScore Score} % Score doesn't change
                        {System.show 'bomb(Pos) : '}
                        {System.show Pos}
                        {Send PGUI spawnBomb(Pos)} % TODO : Pos ou ID Pos ? Juste Pos serait logique. Mais avec ID logique pour donner des points s'il kill qqn
                        {SendBombInfo PPlayers bombPlanted(Pos)}
                        {Send BombPort bomb(turn:NbTurn+Input.timingBomb*Input.nbBombers pos:Pos port:PPlay)}
                        NewMap = Map
                     else raise('Unrecognised msg in function Main.RunTurn') end
                     end
                     NewBombsList = {ProcessBombs BombsList NbTurn HideFPort NewMap NMapProcessBombs ChangeList ChangeList}
                     {Delay 300}
                     {System.show NewBombsList}
                     {RunTurn N-1 NbAlive T NewBombsList NbTurn+1 NewHideFireStream NMapProcessBombs TStream}
                  end
               else raise('Problem in function Main.RunTurn') end
               end
            end
            
         end
      end
      BombsL
      HideFStream
      HideFPort
   in
      BombPort = {NewPort BombsL}
      HideFPort = {NewPort HideFStream}
      {RunTurn Input.nbBombers Input.nbBombers PPlayers BombsL 1 HideFStream Input.map ScoreStream}
   end
   

in
   %% Implement your controller here

   % Create the port for the GUI and initialise it
   PGUI = {GUI.portWindow}
   {Send PGUI buildWindow}
   

   % Create the ports for the players using the PlayerManager and assign its unique ID.
   PScore = {NewPort ScoreStream}
   PPlayers = {CreatePlayers Input.nbBombers Input.colorsBombers Input.bombers}
   
   % Spawn bonuses, boxes and players
   {SpawnMap Input.map PPlayers}
   
   {Delay 5000} % TODO : synchronisation entre fichiers

   if Input.isTurnByTurn then
      {RunTurnByTurn} % TODO un thread ?
   end
   % TODO : else : RunSimul

%% TRES IMPORTANT : rendre les bombes au joueur devrait être fait après le tour d'explosion (ou du moins, après la décision du joueur) je pense. => nouveau port par ex et process le stream après doaction
end
