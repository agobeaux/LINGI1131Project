functor
import
    Browser
    System
    Main
    Input
define
    {System.show 'test'}
    local Z DummyPort DummyStream in
        DummyPort = {NewPort DummyStream}
        Z = {Main.processMove DummyPort pt(x:12 y:2) Input.map}
        {System.show Z}
    end
end