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
   PGUI % GUI Port
   PPlayers % Players Port
   HideFStream % Stream for the hideFire(Pos) signals
   HideFPort = {NewPort HideFStream} % Port for HideFStream

   PlayersLivesStream % Stream with the players'ID and number of lives (ID#NbLives)|T
   PPlayersLives = {NewPort PlayersLivesStream} % Port for PlayersLivesStream
   

   NbDeadsStream % Stream filled with '1' for each dead player
   PNbDeads = {NewPort NbDeadsStream} % Port for NbDeadsStream
   PosPlayersTBT % List with the players' ports and their position (PPlay#Pos)|T

   InitNbBoxes % Initial number of boxes (bonus + point boxes)
   DelayHideF = 100 % in milliseconds, used only in simultaneous

   /**
    * Assigns a port to each player and returns the list of the players' ports.
    *
    * @param      N: number of players we need to create.
    * @param Colors: bombers' colors.
    * @param  Names: bombers' names.
    */
   fun {CreatePlayers N Colors Names}
      if N == 0 then nil
      else
         case Colors#Names of (Color|T1)#(Name|T2) then Bomber in
            Bomber = bomber(id:N color:Color name:Name)
            {Send PGUI initPlayer(Bomber)}
            {PlayerManager.playerGenerator Name Bomber}|{CreatePlayers N-1 T1 T2}
         else nil
         end
      end
   end

   /**
    * Spawns the Map and returns a list containing the player's port and position (Port#Position)|T
    *       and computes the total number of boxes.
    *
    * @param      Map: games' map.
    * @param PPlayers: list with the players' ports.
    * @param ?NbBoxes: unbound, number of boxes on the map.
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
                  {Wait Pos}
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




   fun {ExplodeBomb Pos PortPlayer Map LastEndChangeList PosAndPorts}
      % TODO TRES IMPORTANT : quand y'aura des explosions qui se croisent il faudra bien le gérer... On devra changer la map après tout et pas directement après
      % car sinon un feu pourrait aller plus loin qu'une boîte. => stream avec les endroits à mettre en feu
      proc {HitPlayers PosFire PosAndPorts PlayerHit N}
         if N == 0 then
            skip
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
               if Input.isTurnByTurn then {Send HideFPort hideFire(Pos2)}
               else
                  thread
                     {Delay DelayHideF}
                     {Send HideFPort hideFire(Pos2)}
                  end
               end
               false
            [] 3 then % bonus box
               {Send PGUI hideBox(Pos2)}
               {BroadcastInfo PPlayers boxRemoved(Pos2)}
               {Send PGUI spawnBonus(Pos2)}
               {Send PGUI spawnFire(Pos2)}
               ChangeRecord = X#Y#6
               if Input.isTurnByTurn then {Send HideFPort hideFire(Pos2)}
               else
                  thread
                     {Delay DelayHideF}
                     {Send HideFPort hideFire(Pos2)}
                  end
               end
               false
            [] 1 then false % wall
            else % simple floor, floor with bonus/point, spawn floor (could be a floor with a player)
               % TODO WARNING : attention si on rajoute des éléments le 'else' sera insuffisant...
               {Send PGUI spawnFire(Pos2)}
               if Input.isTurnByTurn then {Send HideFPort hideFire(Pos2)}
               else
                  thread
                     {Delay DelayHideF}
                     {Send HideFPort hideFire(Pos2)}
                  end
               end
               {HitPlayers Pos2 PosAndPorts false Input.nbBombers}
               true % fire goes through people
            end
         end
      end
      proc {ProcessExplodeXM X Y Dx ChangeRecord}
         if {And Dx =< Input.fire X-Dx>0} then X2 DoNext in
            X2 = X - Dx
            {System.show 'in ProcessExplodeXM X#Y#X2#ChangeRecord'#X#Y#X2#ChangeRecord}
            DoNext = {ProcessExplode X2 Y ChangeRecord}
            if DoNext then {ProcessExplodeXM X Y Dx+1 ChangeRecord} end
         end
      end
      proc {ProcessExplodeXP X Y Dx ChangeRecord}
         if {And Dx =< Input.fire X+Dx < Input.nbColumn} then X2 DoNext in
            X2 = X + Dx
            {System.show 'in ProcessExplodeXP X#Y#X2#ChangeRecord'#X#Y#X2#ChangeRecord}
            DoNext = {ProcessExplode X2 Y ChangeRecord}
            if DoNext then {ProcessExplodeXP X Y Dx+1 ChangeRecord} end
         end
      end
      proc {ProcessExplodeYM X Y Dy ChangeRecord}
         if {And Dy =< Input.fire Y-Dy > 0} then Y2 DoNext in
            Y2 = Y - Dy
            {System.show 'in ProcessExplodeYM X#Y#Y2#ChangeRecord'#X#Y#Y2#ChangeRecord}
            DoNext = {ProcessExplode X Y2 ChangeRecord}
            if DoNext then {ProcessExplodeYM X Y Dy+1 ChangeRecord} end
         end
      end
      proc {ProcessExplodeYP X Y Dy ChangeRecord}
         if {And Dy =< Input.fire Y+Dy < Input.nbRow} then Y2 DoNext in
            Y2 = Y + Dy
            {System.show 'in ProcessExplodeYP X#Y#Y2#ChangeRecord'#X#Y#Y2#ChangeRecord}
            DoNext = {ProcessExplode X Y2 ChangeRecord}
            if DoNext then {ProcessExplodeYP X Y Dy+1 ChangeRecord} end
         end
      end
   in
      {System.show 'Im in ExplodeBomb'} % TODO : delete
      {Send PGUI hideBomb(Pos)}
      {Send PortPlayer add(bomb 1 _)}
      {BroadcastInfo PPlayers bombExploded(Pos)}
      case Pos of pt(x:X y:Y) then NewEndChangeList List1 List2 List3 List4 ChangeRecord0 ChangeRecord1 ChangeRecord2 ChangeRecord3 ChangeRecord4 in

         _ = {ProcessExplode X Y ChangeRecord0} % if player is on the bomb, fire should go through player so not a problem if we don't stop the function
         if {Value.isDet ChangeRecord0} then LastEndChangeList = ChangeRecord0|List1
         else LastEndChangeList = List1 end


         {ProcessExplodeXM X Y 1 ChangeRecord1}
         if {Value.isDet ChangeRecord1} then List1 = ChangeRecord1|List2
         else List1 = List2 end

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

      else raise('Problem in function ExplodeBomb : pattern not recognized'#Pos) end
      end
   end
            
   
   fun {ProcessBombs BombsList NbTurn Map NewMap PosPlayersStream NbBoxRemoved}
      fun {SubProcessBombs BombsList ChangeList EndChangeList PosPlayersStream NbBoxRemoved}
         {System.show 'in SubProcessBombs'}
         {System.show NbTurn} % TODO : delete
         if {Not {Value.isDet BombsList}} then
            {System.show 'SubProcessBombs not isDet'}
            EndChangeList = nil % finally ends the list
            {System.show 'ChangeList'#ChangeList}
            NewMap = {BuildNewMapList Map ChangeList 0 NbBoxRemoved}
            {System.show 'NewMap built in SubProcessBombs not isDet'}
            BombsList
         else
            case BombsList
            of bomb(turn:Turn pos:Pos port:PortPlayer)|T then
               {System.show 'in case bomb SubProcessBombs'} % TODO : delete
               if(Turn == NbTurn) then NewEnd in
                  {System.show 'in if SubProcessBombs'}
                  NewEnd = {ExplodeBomb Pos PortPlayer Map EndChangeList PosPlayersStream}
                  {System.show 'ChangeList # EndChangeList # NewEnd'#ChangeList#EndChangeList#NewEnd}
                  {SubProcessBombs T ChangeList NewEnd PosPlayersStream NbBoxRemoved}
               else
                  {System.show 'in else SubProcessBombs'}
                  EndChangeList = nil % finally ends the list
                  NewMap = {BuildNewMapList Map ChangeList 0 NbBoxRemoved}
                  BombsList
               end
            [] H|T then raise('Problem in function SubProcessBombs case H|T') end
            else raise('Problem in function SubProcessBombs else') end
            end
         end
      end
      ChangeL
   in
      {SubProcessBombs BombsList ChangeL ChangeL PosPlayersStream NbBoxRemoved}
   end

   fun {ProcessBombsSimul BombsList Map NewMap PosPlayersStream NbBoxRemoved}
      fun {SubProcessBombsSimul BombsList ChangeList EndChangeList NbBoxRemoved}
         {System.show 'inProcessBombs'}
         if {Not {Value.isDet BombsList}} then
            {System.show 'ProcessBombs not isDet'}
            EndChangeList = nil % finally ends the list
            {System.show 'ChangeList'#ChangeList}
            NewMap = {BuildNewMapList Map ChangeList 0 NbBoxRemoved}
            {System.show 'NewMap built in ProcessBombs not isDet'}
            BombsList
         else
            case BombsList
            of bomb(pos:Pos port:PortPlayer)|T then
               {System.show 'in case bomb ProcessBombs'} % TODO : delete
               local NewEnd in
                  {System.show 'in if ProcessBombs'}
                  NewEnd = {ExplodeBomb Pos PortPlayer Map EndChangeList PosPlayersStream}
                  {System.show 'ChangeList # EndChangeList # NewEnd'#ChangeList#EndChangeList#NewEnd}
                  {SubProcessBombsSimul T ChangeList NewEnd NbBoxRemoved}
               end
            [] H|T then raise('Problem in function ProcessBombs case H|T') end
            else raise('Problem in function ProcessBombs else') end
            end
         end
      end
      ChangeL
   in
      {SubProcessBombsSimul BombsList ChangeL ChangeL NbBoxRemoved}
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
   
   fun {ProcessBonus PPlay Score}
      RandomValue
      Sum
      fun {RandomChoice Prob0 Prob1 Prob2}
         Sum = Prob0+Prob1+Prob2
         RandomValue = {OS.rand} mod Sum
         if RandomValue < Prob0 then 0
         elseif RandomValue < Prob0+Prob1 then 1
         else 2
         end
      end
      Choice
   in
      {System.show 'In ProcessBonus function with PPlay#Score'#PPlay#Score}
      if Input.useExtention then
         Choice = {RandomChoice 4 4 2}
      else
         Choice = {RandomChoice 5 5 0}
      end
      case Choice
      of 0 then % bomb bonus
         {Send PPlay add(bomb 1 _)}
         {System.show 'In ProcessBonus  before returning Score'#Score}
         Score
      [] 1 then ID NewScore in % 10 points bonus
         {Send PPlay add(point 10 NewScore)}
         {Send PPlay getId(ID)}
         {System.show 'before wait ID NewScore'}
         {Wait ID} % TODO : vraiment nécessaire ? ... Le ID n'était pas bound dans un cas...
         {Wait NewScore}
         {System.show 'after wait ID NewScore'}
         {Send PGUI scoreUpdate(ID NewScore)}
         {System.show 'In ProcessBonus  before returning NewScore'#NewScore}
         NewScore
      [] 2 then ID NewScore in % 1 point malus
         {Send PPlay add(point ~1 NewScore)}
         {Send PPlay getId(ID)}
         {System.show 'before wait ID NewScore'}
         {Wait ID} % TODO : vraiment nécessaire ? ... Le ID n'était pas bound dans un cas...
         {Wait NewScore}
         {System.show 'after wait ID NewScore'}
         {Send PGUI scoreUpdate(ID NewScore)}
         {System.show 'In ProcessBonus  before returning NewScore'#NewScore}
         NewScore
      else raise('Error in ProcessBonus function : Choice not recognized'#Choice) end
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
               {System.show 'BuildNewMap - NewRow : before returningvalue'}
               {System.show 'Value|T : '#(Value|T)}
               Value|T % change into Value given
            else H|{NewRow T X ThisX+1}
            end
         else raise('Error in NewRow function : Row != H|T') end
         end
      end
      fun {NewColumns Map X Y ThisY}
         {System.show 'in NewColumns'}
         case Map of H|T then
            if ThisY == Y then Tmp in  % column which should change % TODO : delete Tmp
               Tmp = {NewRow H X 1}
               {System.show 'BuildNewMap - NewColumns : before returning'}
               Tmp|T
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

   fun {GetElt PPlay List}
      {System.show 'GetElt function, PPlay#List :'#PPlay#List}
      case List
      of (Port#Elt)|T then
         if Port == PPlay then
            {System.show 'GetElt function : before returning Elt'#Elt}
            Elt
         else
            {GetElt PPlay T}
         end
      [] nil then raise('Error in GetElt function : Port not found') end
      else raise('Error in GetElt function : pattern not recognized'#List) end
      end
   end

   fun {ProcessMove PPlay Pos Map ScoreList NewScoreList}
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
            NewScoreList = ScoreList
            Map
         [] 1 then raise('Problem in ProcessMove function, moved into a wall !') end
         [] 2 then raise('Problem in ProcessMove function, moved into a point box !') end
         [] 3 then raise('Problem in ProcessMove function, moved into a bonus box !') end
         [] 4 then % Floor with spawn
            NewScoreList = ScoreList
            Map
         [] 5 then NewMap ID NewScore in % point
            {Send PPlay add(point 1 NewScore)}
            NewScoreList = {ChangeList ScoreList PPlay NewScore}
            {Send PPlay getId(ID)}
            {Wait ID} % TODO : nécessaire ? NOK dans le System.show en tout cas....
            {Wait NewScore}
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
            {System.show 'inProcessMove : before BuildNewMap'}
            NewMap = {BuildNewMap Map X Y 0 _} % change tile into simple floor
            {System.show 'After BuildNewMap'}
            NewScoreList = {ChangeList ScoreList PPlay {ProcessBonus PPlay {GetElt PPlay ScoreList}}}
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
         else raise('Error in ChangeList function : pattern not recognized'#PosPlayersList) end
         end
      end
   end

   proc {ShowWinner ScoreL}
      fun {Winner ScoreList CurrWinnerList CurrScore}
         case ScoreList#CurrWinnerList
         of (PPlay#Score|TScoreL)#(WinnerName|TWinnerList) then
            if Score > CurrScore then NewWinner ID in
               {Send PPlay getId(ID)}
               {Wait ID} % TODO : delete, utile que pour débug avec Got ID
               {System.show 'Got ID :'#ID}
               {Winner TScoreL ID|nil Score}
            elseif Score == CurrScore then ID in
               {Send PPlay getId(ID)}
               {Wait ID} % TODO : delete, utile que pour débug avec Got ID
               {System.show 'Score==CurrScore : Got ID :'#ID}
               {Winner TScoreL ID|CurrWinnerList CurrScore}
            else
               {Winner TScoreL CurrWinnerList CurrScore}
            end
         [] nil#_ then
            CurrWinnerList
         else raise('Error in Winner function : pattern not recognized. ScoreList#CurrWinnerList'#ScoreList#CurrWinnerList) end
         end
      end
      WinnerList
      proc{DisplayWinners WinnerList}
         case WinnerList
         of ID|T then
            {Wait ID} % TODO : delete this
            {System.show 'The winner is : '#ID} % TODO : delete this
            {Send PGUI displayWinner(ID)}
            {DisplayWinners T}
         [] nil then skip
         else raise('Error in function DisplayWinners : pattern not recognized'#WinnerList) end
         end
      end
   in
      {System.show 'ScoreL'#ScoreL}
      % PPlaysList might be only a part of PPlayers, that's why we don't stop in the 'nil' case
      WinnerList = {Winner ScoreL dummyID|nil ~1}
      {DisplayWinners WinnerList}
   end

   proc {RunTurnByTurn}
      BombPort
      proc {RunTurn N NbAlive PPlays BombsList NbTurn HideFireStream Map ScoreList PosPlayersList LivesList ListIDLife NbDeadS NbBoxes}
         {System.show 'in RunTurn function with PosPlayersList#ScoreList : '#PosPlayersList#ScoreList}

         if {Or NbAlive=<1 NbBoxes=<0} then % TODO : retirer ce cas vu que géré plus loin et qu'il n'existera normalement pas dès le départ ?
            {ShowWinner ScoreList}
            {System.show 'Hehe game finished'} % TODO : display Winner with ID
         elseif N == 0 then {RunTurn Input.nbBombers NbAlive PPlayers BombsList NbTurn HideFireStream Map ScoreList PosPlayersList LivesList ListIDLife NbDeadS NbBoxes}
         else
            local NewHideFireStream NewBombsList NMapProcessBombs NewLivesList EndListIDLife NewPosPlayersList NbBoxRemoved NewNbAlive NewNbDeadS in
               {System.show 'Before ChangePlayersLivesList'}
               
               
               NewHideFireStream = {ProcessHideF HideFireStream}
               {System.show 'After NewBombsList'}

               NewBombsList = {ProcessBombs BombsList NbTurn Map NMapProcessBombs PosPlayersList NbBoxRemoved} % check function to understand the 2x ChangeList
               NewLivesList = {ChangePlayersLivesList LivesList ListIDLife EndListIDLife PosPlayersList NewPosPlayersList}
               {System.show 'After ChangePlayersLivesList, NewPosPlayersList :'#NewPosPlayersList}
               NewNbAlive = NbAlive - {ProcessDeadStream NbDeadS NewNbDeadS}

               if {Or NbAlive=<1 NbBoxes-NbBoxRemoved=<0} then
                  {ShowWinner ScoreList}
                  {System.show 'Hehe game finished'}
               else
                  case PPlays
                  of (PPlay|T) then ID State Action NewMap in
                     {Send PPlay getState(ID State)}
                     if State == off then % Problem : have to send score to keep ordering
                        {System.show 'State off for ID'#ID}
                        {RunTurn N-1 NewNbAlive T NewBombsList NbTurn+1 NewHideFireStream NMapProcessBombs ScoreList NewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
                     else NewNewPosPlayersList NewScoreList in
                        {Delay 300}
                        {Send PPlay doaction(_ Action)}
                        {Wait Action}
                        case Action
                        of move(Pos) then
                           {System.show 'move(Pos) : '#Pos}
                           NewMap = {ProcessMove PPlay Pos NMapProcessBombs ScoreList NewScoreList}
                           {System.show 'After NewMap = ProcessMove call'}
                           {Send PGUI movePlayer(ID Pos)}
                           NewNewPosPlayersList = {ChangeList NewPosPlayersList PPlay Pos}
                           {System.show 'After call to ChangeList function'}
                           {BroadcastInfo PPlayers movePlayer(ID Pos)}
                        [] bomb(Pos) then
                           NewScoreList = ScoreList
                           {System.show 'bomb(Pos) : '}
                           {System.show Pos}
                           {Send PGUI spawnBomb(Pos)} % TODO : Pos ou ID Pos ? Juste Pos serait logique. Mais avec ID logique pour donner des points s'il kill qqn
                           NewNewPosPlayersList = NewPosPlayersList
                           {BroadcastInfo PPlayers bombPlanted(Pos)}
                           {Send BombPort bomb(turn:NbTurn+Input.timingBomb*Input.nbBombers pos:Pos port:PPlay)}
                           NewMap = NMapProcessBombs
                        else raise('Unrecognised msg in function Main.RunTurn') end
                        end
                        %{System.show 'Before delay'}
                        {Delay 500}
                        %{System.show 'After delay'}
                        %{System.show NewBombsList}
                        {RunTurn N-1 NewNbAlive T NewBombsList NbTurn+1 NewHideFireStream NewMap NewScoreList NewNewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
                     end
                  else raise('Problem in function Main.RunTurn') end
                  end
               end % else of 'if {Or NbAlive=<1 NbBoxes-NbBoxRemoved=<0}'
            end
            
         end
      end
      BombsL
   in
      BombPort = {NewPort BombsL}
      {RunTurn Input.nbBombers Input.nbBombers PPlayers BombsL 1 HideFStream Input.map {MakeScoreList PPlayers} PosPlayersTBT {MakeLivesList Input.nbBombers} PlayersLivesStream NbDeadsStream InitNbBoxes}
   end

   fun {ProcessMoveSimul PPlay Pos Map ScoreList NewScoreList}
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
            NewScoreList = ScoreList
            Map
         [] 1 then raise('Problem in ProcessMove function, moved into a wall !') end
         [] 2 then raise('Problem in ProcessMove function, moved into a point box !') end
         [] 3 then raise('Problem in ProcessMove function, moved into a bonus box !') end
         [] 4 then % Floor with spawn
            NewScoreList = ScoreList
            Map
         [] 5 then NewMap ID NewScore in % point
            {Send PPlay add(point 1 NewScore)}
            {System.show 'ProcessMoveSimul function : case 5 ScoreList:'#ScoreList}
            NewScoreList = {ChangeList ScoreList PPlay NewScore}
            {Send PPlay getId(ID)}
            {Wait ID} % TODO : nécessaire ? Idem poru NewScore
            {Wait NewScore}
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
            {System.show 'after buildnewmap'}
            {System.show 'ProcessMoveSimul function : case 6 ScoreList:'#ScoreList}
            NewScoreList = {ChangeList ScoreList PPlay {ProcessBonus PPlay {GetElt PPlay ScoreList}}} % TODO WARNING WARNING : j'ai mis 0 au lieu de mettre le bon score
            {System.show 'ProcessMove : case Value == 6, map : '}
            {System.show NewMap}
            NewMap
         else raise('Problem in ProcessMove function, map with unknown value') end
         end
      else raise('Error in function ProcessMove, wrong Pos pattern') end
      end
   end

   proc {RunSimultaneous}
      BombPort
      proc {SimulSendActions PlayerPort StopVar} % TODO WARNING WARNING : condition d'arrêt de thread, une variable qui attend d'être bound par ex
         if {Value.isDet StopVar} then
            {System.show 'thread stopped : port'#PlayerPort}
         else ID State in
            {Send PlayerPort getState(ID State)}
            if State == off then
               skip % TODO WARNING : qué passa si state off et il doit respawn ?
            else Action in
               {Send PlayerPort doaction(_ Action)}
               {Wait Action} % Obligatoire pour attendre
               {Send SimulPort PlayerPort#ID#Action}
               {SimulSendActions PlayerPort StopVar}
            end
         end
      end
      % Cette fonction renvoie une liste d'unbound variables afin de mettre aux threads de s'arrêter quand le jeu prend fin
      fun {InitiateSimulThreads PlayersPort}
         case PlayersPort
         of PPlayer|TPPlayer then StopVar in
            thread {SimulSendActions PPlayer StopVar} end
            {System.show 'Player thread initiated'}
            StopVar|{InitiateSimulThreads TPPlayer}
         [] nil then nil
         end
      end
      SimulStream
      SimulPort = {NewPort SimulStream}

      proc {StopGame ListToBind}
         case ListToBind
         of H|T then
            H = 0
            {StopGame T}
         [] nil then skip
         else raise('Error in StopGame function : pattern not recognized'#ListToBind) end
         end
      end

      proc {ProcessStream SimultaneousStream NbAlive BombsStream HideFireStream Map ScoreList PosPlayersList LivesList ListIDLifeChange NbDeadS NbBoxes}
         {System.show 'in ProcessStream function with PosPlayersList#ScoreList#NbAlive : '#PosPlayersList#ScoreList#NbAlive}

         if {Or NbAlive=<1 NbBoxes=<0} then
            {ShowWinner ScoreList}
            {System.show 'Hehe game finished'} % TODO : display Winner with ID
            {StopGame StopVarList}
         else
            local NewHideFireStream NewBombsStream NMapProcessBombs NbBoxRemoved NewLivesList EndListIDLife NewPosPlayersList NewNbAlive NewNbDeadS in
               NewHideFireStream = {ProcessHideF HideFireStream}

               NewBombsStream = {ProcessBombsSimul BombsStream Map NMapProcessBombs PosPlayersList NbBoxRemoved} % check function to understand the 2x ChangeList
               {System.show 'Before ChangePlayersLivesList'}
               NewLivesList = {ChangePlayersLivesList LivesList ListIDLifeChange EndListIDLife PosPlayersList NewPosPlayersList}
               {System.show 'After ChangePlayersLivesList, NewPosPlayersList :'#NewPosPlayersList}
               NewNbAlive = NbAlive - {ProcessDeadStream NbDeadS NewNbDeadS}
               {System.show NewBombsStream}

               if {Or NbAlive=<1 NbBoxes-NbBoxRemoved=<0} then
                  {ShowWinner ScoreList}
                  {System.show 'Hehe game finished'}
                  {StopGame StopVarList}
               else
                  _ = {Record.waitOr '#'(1:SimultaneousStream 2:NewBombsStream 3:NewHideFireStream)} % Utile car évite de rappeler trop de fois la fonction sans rien faire
                  if {Value.isDet SimultaneousStream} then
                     case SimultaneousStream % TODO WARNING : et si unbound : il faut relancer l'appel récursif pour effectuer les changements ou inutile car liste de changements ?
                     of (PlayerPort#ID#Action)|TSimulStream then State NewMap NewNewPosPlayersList NewScoreList in
                        {Send PlayerPort getState(_ State)}
                        
                        if State == off then % Could happen if player dies (without respawning) after sending an action
                           {System.show 'State off for ID'#ID}
                           {ProcessStream TSimulStream NewNbAlive NewBombsStream NewHideFireStream NMapProcessBombs ScoreList NewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
                        else
                           case Action
                           of move(Pos) then
                              {System.show 'move(Pos) : '#Pos}
                              NewMap = {ProcessMoveSimul PlayerPort Pos NMapProcessBombs ScoreList NewScoreList}
                              {System.show 'After NewMap = ProcessMove call'}
                              {Send PGUI movePlayer(ID Pos)}
                              {System.show 'PosPlayersList#NewPosPlayersList'#PosPlayersList#NewPosPlayersList}
                              NewNewPosPlayersList = {ChangeList NewPosPlayersList PlayerPort Pos}
                              {System.show 'After call to ChangeList function'}
                              {BroadcastInfo PPlayers movePlayer(ID Pos)}
                           [] bomb(Pos) then
                              NewScoreList = ScoreList
                              {System.show 'bomb(Pos) : '#Pos}
                              {Send PGUI spawnBomb(Pos)} % TODO : Pos ou ID Pos ? Juste Pos serait logique. Mais avec ID logique pour donner des points s'il kill qqn
                              NewNewPosPlayersList = NewPosPlayersList
                              {BroadcastInfo PPlayers bombPlanted(Pos)}
                              thread
                                 {Delay Input.timingBombMin+({OS.rand} mod (Input.timingBombMax - Input.timingBombMin +1))}
                                 {Send BombPort bomb(pos:Pos port:PlayerPort)} % PlayerPort to give him a bomb when it explodes
                              end
                              NewMap = NMapProcessBombs
                           else raise('Unrecognized msg in function Main.ProcessStream'#Action) end
                           end
                           {ProcessStream TSimulStream NewNbAlive NewBombsStream NewHideFireStream NewMap NewScoreList NewNewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
                        end
                     else raise('Problem in function Main.ProcessStream') end
                     end
                  else % If SimultaneousStream is not det, call the function again to process bombs etc
                     {ProcessStream SimultaneousStream NewNbAlive NewBombsStream NewHideFireStream NMapProcessBombs ScoreList NewPosPlayersList NewLivesList EndListIDLife NewNbDeadS NbBoxes-NbBoxRemoved}
                  end
               end
            end
            
         end
      end
      BombsL
      StopVarList
   in
      BombPort = {NewPort BombsL}
      StopVarList = {InitiateSimulThreads PPlayers}
      {ProcessStream SimulStream Input.nbBombers BombsL HideFStream Input.map {MakeScoreList PPlayers} PosPlayersTBT {MakeLivesList Input.nbBombers} PlayersLivesStream NbDeadsStream InitNbBoxes}


   end

   

   fun {MakeLivesList N}
      if N == 0 then nil
      else
         (N#Input.nbBombers)|{MakeLivesList N-1}
      end
   end

   fun {MakeScoreList PPlays}
      case PPlays
      of PPlay|TPPlay then
         (PPlay#0)|{MakeScoreList TPPlay}
      [] nil then nil
      end
   end

   
in
   %% Implement your controller here

   % Create the port for the GUI and initialise it
   PGUI = {GUI.portWindow}
   {Send PGUI buildWindow}
   

   % Create the ports for the players using the PlayerManager and assign its unique ID.
   PPlayers = {CreatePlayers Input.nbBombers Input.colorsBombers Input.bombers}
   
   

   % Spawn bonuses, boxes and players
   PosPlayersTBT = {SpawnMap Input.map PPlayers InitNbBoxes}
   
   %{Delay 8000} % TODO : synchronisation entre fichiers
   {Wait GUI.windowBuilt}
   {Delay 2000}

   if Input.isTurnByTurn then
      {RunTurnByTurn} % TODO un thread ?
   else
      {RunSimultaneous}
   end
   % TODO : else : RunSimul

%% TRES IMPORTANT : rendre les bombes au joueur devrait être fait après le tour d'explosion (ou du moins, après la décision du joueur) je pense. => nouveau port par ex et process le stream après doaction
end
