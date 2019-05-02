functor
import
   Player000bomber
   %% Add here the name of the functor of a player
   Player001Kardashian
   Player001Tao
   Player001Turing
export
   playerGenerator:PlayerGenerator
define
   PlayerGenerator
in
   fun{PlayerGenerator Kind ID}
      case Kind
      of player000bomber then {Player000bomber.portPlayer ID}
      %% Add here the pattern to recognize the name used in the 
      %% input file and launch the portPlayer function from the functor
      [] kardashian then {Player001Kardashian.portPlayer ID}
      [] tao then {Player001Tao.portPlayer ID}
      [] turing then {Player001Turing.portPlayer ID}
      else
         raise 
            unknownPlayer('Player not recognized by the PlayerManager '#Kind)
         end
      end
   end
end
