/*

Diseña el modelo de la BD para registrar - iniciar sesión
para c/usuario


Pd: Tengo asignado la siguiente credencial para acceder:

---- registro (captura de pantalla) ---  |    --- login/ iniciar sesión (captura de pantalla) ---
userName: tamagotchi                     |    userName: tamagotchi 
email: tamagotchi@gmail.com              |    password: Tamagotchi123!  
password: Tamagotchi123!                 |


OJO: tiene expiración para un dia.. hacer las pruebas en el THUNDER CLEAR
*/

//_____________________________ REGISTRO ____________________
class RegisterResponse {
  final String message;

  RegisterResponse({required this.message}); //Constructor

  factory RegisterResponse.fromJson(Map<String, dynamic> json){
    return RegisterResponse(message: json['message']);
  }

}// Fin Class


//_________________________ INICIAR SESIÓN ____________________
class LoginResponse {
  final String token;
  final DateTime expiration;

  //constructor
  LoginResponse({
    required this.token,
    required this.expiration
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json){
    return LoginResponse(
      token: json['token'],
      expiration: DateTime.parse(json['expiration']),
    );
  }
}



