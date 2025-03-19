package armory.trait;

import iron.Trait;
import iron.math.Vec4;
import iron.system.Input;
import iron.object.Object;
import iron.object.CameraObject;
import armory.trait.physics.PhysicsWorld;
import armory.trait.physics.RigidBody;
import kha.FastFloat;
//from iron import system

class FirstPersonController extends Trait {

    #if (!arm_physics)
        public function new() { super(); }
    #else

        // Variables públicas ajustables desde el editor
        @prop public var rotationSpeed:Float = 0.15; // Velocidad de rotación
        @prop public var maxPitch:Float = 2.2; // Ángulo máximo de inclinación vertical
        @prop public var minPitch:Float = 0.5; // Ángulo mínimo de inclinación vertical
        @prop public var enableJump:Bool = true; // Habilitar el salto
        @prop public var jumpForce:Float = 16.0; // Fuerza del salto
        @prop public var moveSpeed:Float = 500.0; // Velocidad de movimiento

        @prop public var forwardKey:String = "w"; // Tecla para moverse hacia adelante
        @prop public var backwardKey:String = "s"; // Tecla para moverse hacia atrás
        @prop public var leftKey:String = "a"; // Tecla para moverse hacia la izquierda
        @prop public var rightKey:String = "d"; // Tecla para moverse hacia la derecha
        @prop public var jumpKey:String = "space"; // Tecla para saltar

        @prop public var allowAirJump:Bool = false; // Permitir saltar en el aire

        @prop public var canRun:Bool = true; // Permitir correr
        @prop public var runKey:String = "shift"; // Tecla para correr
        @prop public var runVelocity:Float = 200.0; // Velocidad al correr

        // Variables privadas
        var head:CameraObject; // Cámara del jugador
        var pitch:Float = 0.0; // Inclinación vertical de la cámara
        var body:RigidBody; // Cuerpo rígido del jugador
        var moveForward:Bool = false; // Estado de movimiento hacia adelante
        var moveBackward:Bool = false; // Estado de movimiento hacia atrás
        var moveLeft:Bool = false; // Estado de movimiento hacia la izquierda
        var moveRight:Bool = false; // Estado de movimiento hacia la derecha
        var isRunning:Bool = false; // Estado de correr

        var canJump:Bool = true; // Si puede saltar


        // else return iron.system.Time.delta; // esto retorna delta.time

        // Inicialización
        public function new() {
            super();
            iron.Scene.active.notifyOnInit(init);
        }

        function init() {
            // Obtener los componentes necesarios
            body = object.getTrait(RigidBody);
            head = object.getChildOfType(CameraObject);
            PhysicsWorld.active.notifyOnPreUpdate(preUpdate); // Notificar al mundo físico para pre-actualización
            notifyOnUpdate(update); // Notificar la actualización principal
            notifyOnRemove(removed); // Notificar al eliminar el trait
        }

        var zVec = Vec4.zAxis(); // Vector para rotación en el eje Z
        function preUpdate() {
            if (Input.occupied || body == null) return; // Si hay input ocupado o cuerpo nulo, no hacer nada
            var mouse = Input.getMouse();
            var kb = Input.getKeyboard();

            // Bloquear/desbloquear el mouse con "escape"
            if (mouse.started() && !mouse.locked)
                mouse.lock();
            else if (kb.started("escape") && mouse.locked)
                mouse.unlock();

            // Rotar la cámara según el movimiento del mouse
            if (mouse.locked || mouse.down()) {
                var deltaTime:Float = iron.system.Time.delta; // Obtener el deltaTime para ajustar la velocidad
                object.transform.rotate(zVec, -mouse.movementX * rotationSpeed * deltaTime); // Rotación horizontal
                var deltaPitch:Float = -(mouse.movementY * rotationSpeed * deltaTime); // Rotación vertical
                pitch += deltaPitch;
                pitch = Math.max(minPitch, Math.min(maxPitch, pitch)); // Limitar el rango de inclinación
                head.transform.setRotation((pitch : kha.FastFloat), (0.0 : kha.FastFloat), (0.0 : kha.FastFloat)); // Aplicar la rotación
                body.syncTransform(); // Sincronizar la transformación del cuerpo
            }
        }

        function removed() {
            PhysicsWorld.active.removePreUpdate(preUpdate); // Eliminar la pre-actualización al quitar el trait
        }

        var dir:Vec4 = new Vec4(); // Dirección de movimiento
        function update() {
            if (body == null) return; // Si no hay cuerpo rígido, salir
            var deltaTime:Float = iron.system.Time.delta; // Obtener deltaTime

            // Entradas del teclado para movimiento
            moveForward = Input.getKeyboard().down(forwardKey);
            moveBackward = Input.getKeyboard().down(backwardKey);
            moveLeft = Input.getKeyboard().down(leftKey);
            moveRight = Input.getKeyboard().down(rightKey);
            isRunning = canRun && Input.getKeyboard().down(runKey);

            // Verificar si el jugador está tocando el suelo
            var isGrounded:Bool = false;
            #if arm_physics
            if (!allowAirJump) {
                var vel = body.getLinearVelocity();
                if (Math.abs(vel.z) < 0.1) {
                    isGrounded = true;
                }
            }
            #end

            // Verificar si el jugador puede saltar
            if (!allowAirJump && isGrounded) {
                canJump = true;
            }
            if (allowAirJump) {
                canJump = true;
            }

            // Realizar el salto
            if (enableJump && Input.getKeyboard().started(jumpKey) && canJump) {
                body.applyImpulse(new Vec4(0, 0, jumpForce)); // Aplicar impulso para saltar
                if (!allowAirJump) {
                    canJump = false; // Deshabilitar salto si no se permite saltar en el aire
                }
            }

            // Definir la dirección de movimiento
            dir.set(0, 0, 0);
            if (moveForward) dir.add(object.transform.look());
            if (moveBackward) dir.add(object.transform.look().mult(-1));
            if (moveLeft) dir.add(object.transform.right().mult(-1));
            if (moveRight) dir.add(object.transform.right());

            var btvec = body.getLinearVelocity(); // Obtener la velocidad actual
            body.setLinearVelocity(0.0, 0.0, btvec.z - 1.0); // Ajustar la velocidad en Z

            // Movimiento del jugador
            if (moveForward || moveBackward || moveLeft || moveRight) {
                var dirN = dir.normalize(); // Normalizar la dirección
                var currentSpeed = moveSpeed; // Usar la velocidad base

                // Aumentar la velocidad si está corriendo
                if (isRunning && moveForward) {
                    currentSpeed += runVelocity;
                }

                // Ajustar la velocidad por deltaTime
                dirN.mult(currentSpeed * deltaTime); // Multiplicar por deltaTime para un movimiento consistente
                body.activate();
                body.setLinearVelocity(dirN.x, dirN.y, btvec.z - 1.0); // Aplicar la nueva velocidad
            }

            body.setAngularFactor(0, 0, 0); // Desactivar la rotación
            head.buildMatrix(); // Construir la matriz de la cámara
        }

    #end
}


// posible correcion de delta time