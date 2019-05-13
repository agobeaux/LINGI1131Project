functor
export
   isTurnByTurn:IsTurnByTurn
   useExtention:UseExtention
   printOK:PrintOK
   nbRow:NbRow
   nbColumn:NbColumn
   map:Map
   nbBombers:NbBombers
   bombers:Bombers
   colorsBombers:ColorBombers
   nbLives:NbLives
   nbBombs:NbBombs
   thinkMin:ThinkMin
   thinkMax:ThinkMax
   fire:Fire
   timingBomb:TimingBomb
   timingBombMin:TimingBombMin
   timingBombMax:TimingBombMax
define
   IsTurnByTurn UseExtention PrintOK
   NbRow NbColumn Map
   DEFAULTNbRow DEFAULTNbColumn DEFAULTMap
   FIRSTNbRow FIRSTNbCol FIRSTMap
   SECONDNbRow SECONDNbCol SECONDMap
   THIRDNbRow THIRDNbCol THIRDMap
   NbBombers Bombers ColorBombers
   NbLives NbBombs
   ThinkMin ThinkMax
   TimingBomb TimingBombMin TimingBombMax Fire
in 


%%%% Style of game %%%%
   
   IsTurnByTurn = true
   UseExtention = true
   PrintOK = true


%%%% Description of the map %%%%
   
   NbRow = DEFAULTNbRow
   NbColumn = DEFAULTNbColumn
   Map = DEFAULTMap

   DEFAULTNbRow = 7
   DEFAULTNbColumn = 13
   DEFAULTMap = [[1 1 1 1 1 1 1 1 1 1 1 1 1]
	  [1 4 0 2 2 2 2 2 2 2 0 4 1]
	  [1 0 1 3 1 2 1 2 1 2 1 0 1]
	  [1 2 2 2 3 2 2 2 2 3 2 2 1]
	  [1 0 1 2 1 2 1 3 1 2 1 0 1]
	  [1 4 0 2 2 2 2 2 2 2 0 4 1]
	  [1 1 1 1 1 1 1 1 1 1 1 1 1]]

   FIRSTNbRow = 7
   FIRSTNbCol = 7
   FIRSTMap = [[1 1 1 1 1 1 1]
      [1 4 0 2 0 4 1]
      [1 0 2 3 2 0 1]
      [1 2 2 3 2 2 1]
      [1 0 2 3 2 0 1]
      [1 4 0 2 0 4 1]
      [1 1 1 1 1 1 1]]

   SECONDNbRow = 15
   SECONDNbCol = 15
   SECONDMap = [[1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]
   [1 4 0 2 2 2 2 3 2 2 2 2 0 4 1]
   [1 0 2 2 1 1 2 3 1 1 1 1 2 0 1]
   [1 2 2 1 0 0 1 2 2 2 1 2 2 2 1]
   [1 2 2 1 0 0 1 2 2 1 2 2 2 2 1]
   [1 2 2 2 1 1 2 2 1 1 1 1 2 2 1]
   [1 2 2 2 2 2 2 0 2 2 2 2 2 2 1]
   [1 2 2 2 2 2 0 4 0 2 2 2 2 2 1]
   [1 2 2 2 2 2 2 0 2 2 2 2 2 2 1]
   [1 2 2 2 1 1 2 3 1 1 1 1 2 2 1]
   [1 2 2 1 0 0 1 2 2 2 1 2 2 2 1]
   [1 2 2 1 0 0 1 2 2 1 2 2 2 2 1]
   [1 0 2 2 1 1 2 2 1 1 1 1 2 0 1]
   [1 4 0 2 2 2 2 2 2 2 2 2 0 4 1] % mirror
   [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]]

   THIRDNbRow = 7
   THIRDNbCol = 7
   THIRDMap = [[1 1 1 1 1 1 1]
   [1 4 0 1 0 4 1]
   [1 0 3 1 3 0 1]
   [1 3 3 1 3 3 1]
   [1 3 3 1 3 3 1]
   [1 3 3 1 3 3 1]
   [1 1 1 1 1 1 1]]

%%%% Players description %%%%

   NbBombers = 2
   Bombers = [turing dijkstra]
   ColorBombers = [red green]

%%%% Parameters %%%%

   NbLives = 3
   NbBombs = 1
 
   ThinkMin = 1000  % in millisecond
   ThinkMax = 1000 % in millisecond
   
   Fire = 3
   TimingBomb = 3
   TimingBombMin = 3000 % in millisecond
   TimingBombMax = 3000 % in millisecond

end
