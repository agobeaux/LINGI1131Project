functor
import
   Player000bomber
   %% Add here the name of the functor of a player
   Player001Kardashian
   Player001Tao
   Player001Turing
   Player055Clever
   Player013smart
   Player100advanced
   Player038Luigi
   Player100JonSnow
   Player009defense
   Player009notsafedefense
   Player017advanced
   Player010IA2
   Player007Scared
   Player055survivor
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
      [] player055Clever then {Player055Clever.portPlayer ID}
      [] player013smart then {Player013smart.portPlayer ID}
      [] player100advanced then {Player100advanced.portPlayer ID}
      [] player038Luigi then {Player038Luigi.portPlayer ID}
      [] player100JonSnow then {Player100JonSnow.portPlayer ID}
      [] player009defense then {Player009defense.portPlayer ID}
      [] player009notsafedefense then {Player009notsafedefense.portPlayer ID}
      [] player017advanced then {Player017advanced.portPlayer ID}
      [] player010IA2 then {Player010IA2.portPlayer ID}
      [] player007Scared then {Player007Scared.portPlayer ID}
      [] player055survivor then {Player055survivor.portPlayer ID}
      else
         raise 
            unknownPlayer('Player not recognized by the PlayerManager '#Kind)
         end
      end
   end
end
