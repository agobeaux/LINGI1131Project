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
   fun {SpawnMap Map PPlayers NbBoxes}
      
      fun {ProcessElt IdSquare X Y BoxThere}
         case IdSquare
         of 4 then
            BoxThere = 0
            pt(x:X y:Y)|nil % spawn
         % other cases not needed since points and bonuses should spawn only when boxes get destroyed
         [] 2 then
            BoxThere = 1
            nil
         [] 3 then
            BoxThere = 1
            nil
         else % wall / empty : rien à faire
            BoxThere = 0
            nil
         end
      end
      fun {SpawnRow Row X Y AccNbBoxRow NbBoxRow}
         case Row
         of H|T then Z W DeltaNbBox in
            Z = {ProcessElt H X Y DeltaNbBox}
            W = {SpawnRow T X+1 Y AccNbBoxRow+DeltaNbBox NbBoxRow}
            {Append Z W}
         [] nil then
            NbBoxRow = AccNbBoxRow
            nil
         end
      end
      fun {SpawnEntire Col Y AccNbBox NbBox}
         case Col
         of H|T then Z NbBoxRow in
            Z = {SpawnRow H 1 Y 0 NbBoxRow}
            {Append Z {SpawnEntire T Y+1 AccNbBox+NbBoxRow NbBox}}
         [] nil then
            NbBox = AccNbBox
            nil
         end
      end
      Spawns
      fun {SpawnPlayers N PPlays SpawnList}
         if N == 0 then nil
         else
            case PPlays#SpawnList of (PPlay|T1)#(Spawn|T2) then ID Pos RealID in
               {Send PPlay assignSpawn(Spawn)}
               {Send PPlay spawn(ID Pos)}
               {Send PPlay getId(RealID)}
               if {Or ID \= RealID  Pos \= Spawn} then {System.show ID#N} raise('Error, Player spawned at wrong place') end end
               {Send PGUI spawnPlayer(ID Pos)}
               {BroadcastInfo PPlayers spawnPlayer(ID Pos)}
               (PPlay#Pos)|{SpawnPlayers N-1 T1 T2}
            end
         end
      end
   in
      Spawns = {SpawnEntire Map 1 0 NbBoxes}
      {SpawnPlayers Input.nbBombers PPlayers Spawns} % returns the spawns of the players (and their port) (initial positions)
      
   end

   
   proc {BroadcastInfo PPlayersList Info} % TODO WARNING : Il faudrait check le state d'abord en fait... Si les joueurs peuvent ne plus répondre... Mais osef s'ils répondent pas je pense pour le broadcast
      case PPlayersList of PortP|T then 
         {Send PortP info(Info)}
         {BroadcastInfo T Info}
      [] nil then skip
      else raise('Error in BroadcastInfo for msg :'#Info) end
      end
   end
   
   fun {ChangePlayersLivesList LivesList ListIDLife ?EndListIDLife PosList ?NewPosList} % TODO WARNING : si on change l'ordering de 1->N plutôt que N->1, il faut changer ici aussi
      fun {ChangePlayersLives LivesList Elem N PosList ?NewPosList} % TODO WARNING : intéressant à faire : avec un getID par exemple
         if N == 0 then
            raise('Error in ChangePlayersLives function : N==0, did not find player') end
         else
            case Elem|LivesList|PosList
            of (IDElem#NbLives)|(Lives|TLivesList)|((PPlay#LastPos)|TPortPos) then ID in
               {Send PPlay getId(ID)}
               if IDElem == ID then Pos in
                  {Send PPlay spawn(_ Pos)}
                  {Send PGUI spawnPlayer(ID Pos)}
                  NewPosList = (PPlay#Pos)|TPortPos
                  {BroadcastInfo PPlayers spawnPlayer(ID Pos)}
                  NbLives|TLivesList
               else
                  local TNewPosList in
                     NewPosList = (PPlay#LastPos)|TNewPosList
                     Lives|{ChangePlayersLives TLivesList Elem N-1 TPortPos TNewPosList}
                  end
               end
            else raise('Error in ChangePlayersLives function : pattern not recognized'#Elem|LivesList) end
            end
         end
      end
   in
      if {Not {Value.isDet ListIDLife}} then
         {System.show 'Value not det'}
         NewPosList = PosList
         EndListIDLife = ListIDLife
         LivesList
      else
         {System.show 'Value det'#ListIDLife}
         case ListIDLife
         of H|T then NewPosListSub in
            {ChangePlayersLivesList {ChangePlayersLives LivesList H Input.nbBombers PosList NewPosListSub} T EndListIDLife NewPosListSub NewPosList}
         [] nil then
            NewPosList = PosList
            LivesList
         else raise('Error in ChangePlayersLivesList function : pattern not recognized'#ListIDLife) end
         end
      end
   end




   fun {ExplodeBomb Pos PortPlayer HideFPort Map LastEndChangeList PosAndPorts}
      % TODO TRES IMPORTANT : quand y'aura des explosions qui se croisent il faudra bien le gérer... On devra changer la map après tout et pas directement après
      % car sinon un feu pourrait aller plus loin qu'une boîte. => stream avec les endroits à mettre en feu
      fun {HitPlayers PosFire PosAndPorts PlayerHit N}
         if N == 0 then
            PlayerHit
         else
            case PosAndPorts
            of (PPlay#PosPlayer)|T then
               if PosFire == PosPlayer then ID Result in % est-ce suffisant ? ou doit-on décortiquer en X et Y ?
                  {Send PPlay gotHit(ID Result)} % TODO WARNING : faire gaffe au State d'abord ?... Il faudrait pour interop ou alors changer la position quand le gars est mort
                  {System.show 'PosFire=PosPlayer : PosFire#PosPlayer#ID#Result'#PosFire#PosPlayer#ID#Result}
                  case Result
                  of death(NewLife) then % player just got killed 
                     {BroadcastInfo PPlayers deadPlayer(ID)}
                     % TODO : vérifier si le state devient bien off ?
                     {Send PGUI hidePlayer(ID)}
                     {Send PGUI lifeUpdate(ID NewLife)}
                     if NewLife > 0 then
                        {Send PPlayersLives ID#NewLife}
                     else
                        {Send PNbDeads 1}
                     end
                     {HitPlayers PosFire T true N-1}
                  [] null then % player already killed during this turn
                     {HitPlayers PosFire T true N-1} % player was hit during this turn so it should return true
                     % TODO WARNING : spawn should be done before calling ProcessBombs so that the player can get killed at the turn he respawns
                  else raise('Error in HitPlayers function : Result : pattern not recognized'#Result) end
                  end
               else % this player was not it during this turn
                  {System.show 'PosFire != PosPlayer : PosFire#PosPlayer#N'#PosFire#PosPlayer#N}
                  {HitPlayers PosFire T PlayerHit N-1}
               end
            else raise('Error in HitPlayers function : PosAndPorts : pattern not recognized'#PosAndPorts) end
            end
         end
      end
      fun {ProcessExplode X Y ChangeRecord} % TODO : WARNING : simultaneous il faudra le même map pour tous les joueurs
         {System.show 'Im in ProcessExplode !!!!!!!!!!!!!'} % TODO : delete
         local Pos2 in
            Pos2 = pt(x:X y:Y)
            case {Nth {Nth Map Y} X}
            of 2 then % point box
               {Send PGUI hideBox(Pos2)}
               {BroadcastInfo PPlayers boxRemoved(Pos2)}
               {Send PGUI spawnPoint(Pos2)}
               {Send PGUI spawnFire(Pos2)}
               ChangeRecord = X#Y#5
               {Send HideFPort hideFire(Pos2)}
               false
            [] 3 then % bonus box
               {Send PGUI hideBox(Pos2)}
               {BroadcastInfo PPlayers boxRemoved(Pos2)}
               {Send PGUI spawnBonus(Pos2)}
               {Send PGUI spawnFire(Pos2)}
               ChangeRecord = X#Y#6
               {Send HideFPort hideFire(Pos2)}
               false
            [] 1 then false % wall
            else % simple floor, floor with bonus/point, spawn floor (could be a floor with a player)
               % TODO WARNING : attention si on rajoute des éléments le 'else' sera insuffisant...
               {Send PGUI spawnFire(Pos2)}
               {Send HideFPort hideFire(Pos2)}
               {Not {HitPlayers Pos2 PosAndPorts false Input.nbBombers}} % returns true if no player was hit
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
      {BroadcastInfo PPlayers bombExploded(Pos)}
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

         {System.show 'LastEndChangeList'#LastEndChangeList}
         {System.show 'NewEndChangeList'#NewEndChangeList}

         NewEndChangeList % returns the new unbound end of ChangeList so that we can append lists of changes from other
         % bombs exploding during the same turn (debugs border case when 2 bombs want to explode the same box : fire doesn't go further for any of the bombs)

      else raise('Problem in function ExplodeBomb') end
      end
   end
            
   
   fun {ProcessBombs BombsList NbTurn HideFPort Map NewMap ChangeList EndChangeList PosPlayersStream NbBoxRemoved}
      {System.show 'inProcessBombs'}
      {System.show NbTurn} % TODO : delete
      if {Not {Value.isDet BombsList}} then
         {System.show 'ProcessBombs not isDet'}
         EndChangeList = nil % finally ends the list
         {System.show 'ChangeList'#ChangeList}
         NewMap = {BuildNewMapList Map ChangeList 0 NbBoxRemoved}
         {System.show 'NewMap built in ProcessBombs not isDet'}
         BombsList
      else
         case BombsList
         of bomb(turn:Turn pos:Pos port:PortPlayer)|T then
            {System.show 'in case bomb ProcessBombs'} % TODO : delete
            if(Turn == NbTurn) then NewEnd in
               {System.show 'in if ProcessBombs'}
               NewEnd = {ExplodeBomb Pos PortPlayer HideFPort Map EndChangeList PosPlayersStream}
               {System.show 'ChangeList # EndChangeList # NewEnd'#ChangeList#EndChangeList#NewEnd}
               {ProcessBombs T NbTurn HideFPort Map NewMap ChangeList NewEnd PosPlayersStream NbBoxRemoved}
            else
               {System.show 'in else ProcessBombs'}
               EndChangeList = nil % finally ends the list
               NewMap = {BuildNewMapList Map ChangeList 0 NbBoxRemoved}
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
         {Send PPlay add(bomb 1 _)}
         {Send PScore Score}
      [] 1 then ID NewScore in
         {Send PPlay add(point 10 NewScore)}
         {Send PScore NewScore}
         {Send PPlay getId(ID)}
         {Send PGUI scoreUpdate(ID NewScore)}
      end
   end

   % TODO : en simultané, ils pourront être en même temps sur une case BONUS : à gérer : +le total pour chacun ? + la moitié ? Random give ? give au premier dans notre liste (unfair) ?

   fun {BuildNewMapList Map List Acc TotNbChanges}
      if {Value.isFree List} then {System.show 'UNBOUND LIST !!! BuildNewMapList'} end % TODO : delete
      case List
      of (X#Y#Value)|T then NbChange ReturnVal in
         {BuildNewMapList {BuildNewMap Map X Y Value NbChange} T Acc+NbChange TotNbChanges}
      [] nil then
         {System.show 'Leaving BuildNewMapList'}
         TotNbChanges = Acc
         Map % TODO : delete show
      else raise('Error in BuildNewMapList : list pattern not recognized') end
      end
   end

   fun {BuildNewMap Map X Y Value NbChange}
      fun {NewRow Row X ThisX}
         {System.show 'in NewRow'}
         case Row of H|T then
            if X == ThisX then
               if {Or H==2 H==3} then % we have a point box or bonus box and we destroy it
                  NbChange = 1
               else NbChange = 0 end
               Value|T % change into Value given
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
         [] 5 then NewMap ID NewScore in % point
            {Send PPlay add(point 1 NewScore)}
            {Send PScore NewScore}
            {Send PPlay getId(ID)}
            {Send PGUI scoreUpdate(ID NewScore)}
            {Send PGUI hidePoint(Pos)}
            % make this tile a floor :
            NewMap = {BuildNewMap Map X Y 0 _} % change tile into simple floor
            {System.show 'ProcessMove : case Value == 5, map : '}
            {System.show NewMap}
            NewMap
         [] 6 then Z NewMap in % bonus
            % TODO : ProcessBonus (and send sth to the player)
            {Send PGUI hideBonus(Pos)}
            NewMap = {BuildNewMap Map X Y 0 _} % change tile into simple floor
            {ProcessBonus PPlay PScore Score}
            {System.show 'ProcessMove : case Value == 6, map : '}
            {System.show NewMap}
            NewMap
         else raise('Problem in ProcessMove function, map with unknown value') end
         end
      else raise('Error in function ProcessMove, wrong Pos pattern') end
      end
   end
   
   fun {ProcessDeadStream NbDeadS ?NewNbDeadS}
      fun {ProcessDeadStreamAcc NbDeadS ?NewNbDeadS Acc}
         if {Not {Value.isDet NbDeadS}} then
            NewNbDeadS = NbDeadS
            Acc
         else
            case NbDeadS
            of H|T then
               {ProcessDeadStreamAcc T NewNbDeadS Acc+H}
            else
               raise('Error in ProcessDeadStreamAcc function : pattern not recognized'#NbDeadS) end
            end
         end
      end
   in
      {ProcessDeadStreamAcc NbDeadS NewNbDeadS 0}
   end

   fun {ChangeList PosPlayersList PPlay Pos} % TODO WARNING : l'idéal serait d'avoir une fonction générale qui donne l'index mais il faudrait être sûr qu'on ne changera pas le mauvais port...
      {System.show 'In ChangeList function, PosPlayersList : '#PosPlayersList}
      if {Not {Value.isDet PosPlayersList}} then raise('Error in ChangeList function, PosPlayersList not bound')end
      else
         case PosPlayersList
         of (PortElt#PosElt)|T then
            if PPlay == PortElt then (PPlay#Pos)|T
            else (PortElt#PosElt)|{ChangeList T PPlay Pos} end
         [] nil then raise('Error in ChangeList function : did not find player (port)') end
         else raise('Error in ChangeList function : pattern not recognized') end
         end
      end
   end

   proc {ShowWinner PPlaysList ScoreStream}
      fun {Winner PPlays ScoreList CurrWinner N}
         if N == 0 then CurrWinner
         else
            case PPlays
            of PPlay|TPPlay then
               case ScoreList#CurrWinner
               of (Score|TScore)#(Name|WinnerScore) then
                  if Score > WinnerScore then NewWinner ID in
                     {Send PPlay getId(ID)}
                     {Wait ID} % TODO : delete, utile que pour débug avec Got ID
                     {System.show 'Got ID :'#ID}
                     {Winner TPPlay TScore ID|Score N-1}
                  else
                     {Winner TPPlay TScore CurrWinner N-1}
                  end
               else raise('Error in Winner function : pattern not recognized. ScoreList#CurrWinner'#ScoreList#CurrWinner) end
               end
            [] nil then {Winner PPlayers ScoreList CurrWinner N}
            end
         end
      end
      NameScore
   in
      {System.show 'ScoreStream'#ScoreStream}
      % PPlaysList might be only a part of PPlayers, that's why we don't stop in the 'nil' case
      NameScore = {Winner PPlaysList ScoreStream dummyID|(~1) Input.nbBombers}
      case NameScore of Name|_ then
         {Send PGUI displayWinner(Name)}
         {Wait Name}
         {System.show 'The winner is : '}
         {System.show Name}
      end
   end

   proc {RunTurnByTurn}
      BombPort
      proc {RunTurn N NbAlive PPlays BombsList NbTurn HideFireStream Map ScoreStream PosPlayersList LivesList ListIDLife NbDeadS NbBoxes}
         {System.show 'in RunTurn function with PosPlayersList#ScoreStream : '#PosPlayersList#ScoreStream}

         if {Or NbAlive=<1 NbBoxes=<0} then
            {ShowWinner PPlays ScoreStream}
            {System.show 'Hehe game finished'} % TODO : display Winner with ID
         elseif N == 0 then {RunTurn Input.nbBombers NbAlive PPlayers BombsList NbTurn HideFireStream Map ScoreStream PosPlayersList LivesList ListIDLife NbDeadS NbBoxes}
         else
            local NewBombsList NewHideFireStream NMapProcessBombs NewLivesList EndListIDLife NewPosPlayersList in
               {System.show 'Before ChangePlayersLivesList'}
               NewLivesList = {ChangePlayersLivesList LivesList ListIDLife EndListIDLife PosPlayersList NewPosPlayersList}
               {System.show 'After ChangePlayersLivesList, NewPosPLayersList :'#NewPosPlayersList}
               NewHideFireStream = {ProcessHideF HideFireStream}
               {System.show 'After NewBombsList'}
               case PPlays#ScoreStream
               of (PPlay|T)#(Score|TStream) then ID State Action NewMap MapChangeList NewNbAlive NewNbDeadS NbBoxRemoved in
                  {Send PPlay getState(ID State)}
                  if State == off then % Problem : have to send score to keep ordering
                     {Send PScore Score}
                     {System.show 'State off for ID'#ID}
                     NewBombsList = {ProcessBombs BombsList NbTurn HideFPort Map NMapProcessBombs MapChangeList MapChangeList NewPosPlayersList NbBoxRemoved} % check function to understand the 2x ChangeList
                     NewNbAlive = NbAlive - {ProcessDeadStream NbDeadS NewNbDeadS}
                     {RunTurn N-1 NewNbAlive T BombsList NbTurn+1 NewHideFireStream NMapProcessBombs TStream NewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
                  else NewNewPosPlayersList NewNbAlive NewNbDeadS in
                     {Send PPlay doaction(_ Action)}
                     case Action
                     of move(Pos) then
                        {System.show 'move(Pos) : '#Pos}
                        NewMap = {ProcessMove PPlay Pos Map Score}
                        {System.show 'After NewMap = ProcessMove call'}
                        {Send PGUI movePlayer(ID Pos)}
                        NewNewPosPlayersList = {ChangeList NewPosPlayersList PPlay Pos}
                        {System.show 'After call to ChangeList function'}
                        {BroadcastInfo PPlayers movePlayer(ID Pos)}
                     [] bomb(Pos) then
                        {Send PScore Score} % Score doesn't change
                        {System.show 'bomb(Pos) : '}
                        {System.show Pos}
                        {Send PGUI spawnBomb(Pos)} % TODO : Pos ou ID Pos ? Juste Pos serait logique. Mais avec ID logique pour donner des points s'il kill qqn
                        NewNewPosPlayersList = NewPosPlayersList
                        {BroadcastInfo PPlayers bombPlanted(Pos)}
                        {Send BombPort bomb(turn:NbTurn+Input.timingBomb*Input.nbBombers pos:Pos port:PPlay)}
                        NewMap = Map
                     else raise('Unrecognised msg in function Main.RunTurn') end
                     end
                     NewBombsList = {ProcessBombs BombsList NbTurn HideFPort NewMap NMapProcessBombs MapChangeList MapChangeList NewNewPosPlayersList NbBoxRemoved} % check function to understand the 2x ChangeList
                     NewNbAlive = NbAlive - {ProcessDeadStream NbDeadS NewNbDeadS}
                     {System.show 'Before delay'}
                     {Delay 500}
                     {System.show 'After delay'}
                     {System.show NewBombsList}
                     {RunTurn N-1 NewNbAlive T NewBombsList NbTurn+1 NewHideFireStream NMapProcessBombs TStream NewNewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
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
      {RunTurn Input.nbBombers Input.nbBombers PPlayers BombsL 1 HideFStream Input.map ScoreStream PosPlayersTBT {MakeLivesList Input.nbBombers} PlayersLivesStream NbDeadsStream InitNbBoxes}
   end

   PPlayersLives
   PlayersLivesStream

   fun {MakeLivesList N}
      if N == 0 then nil
      else
         (N#Input.nbBombers)|{MakeLivesList N-1}
      end
   end

   NbDeadsStream
   PNbDeads = {NewPort NbDeadsStream}
   PosPlayersTBT

   InitNbBoxes
in
   %% Implement your controller here

   % Create the port for the GUI and initialise it
   PGUI = {GUI.portWindow}
   {Send PGUI buildWindow}
   

   % Create the ports for the players using the PlayerManager and assign its unique ID.
   PScore = {NewPort ScoreStream}
   PPlayers = {CreatePlayers Input.nbBombers Input.colorsBombers Input.bombers}
   
   PPlayersLives = {NewPort PlayersLivesStream} % will help to construct lists with the number of player's lives

   % Spawn bonuses, boxes and players
   PosPlayersTBT = {SpawnMap Input.map PPlayers InitNbBoxes}
   
   %{Delay 8000} % TODO : synchronisation entre fichiers
   {Wait GUI.windowBuilt}
   {Delay 500}

   if Input.isTurnByTurn then
      {RunTurnByTurn} % TODO un thread ?
   end
   % TODO : else : RunSimul

%% TRES IMPORTANT : rendre les bombes au joueur devrait être fait après le tour d'explosion (ou du moins, après la décision du joueur) je pense. => nouveau port par ex et process le stream après doaction
end
