import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const BASE_URL = "https://ganacol-backend-production.up.railway.app";

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? sponsorId;

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  void initDeepLinks() async {
    final appLinks = AppLinks();

    final uri = await appLinks.getInitialAppLink();

    if (uri != null && uri.queryParameters['ref'] != null) {
      setState(() {
        sponsorId = uri.queryParameters['ref'];
      });
    }

    appLinks.uriLinkStream.listen((uri) {
      if (uri.queryParameters['ref'] != null) {
        setState(() {
          sponsorId = uri.queryParameters['ref'];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: sponsorId != null
          ? RegisterPage(sponsorId: sponsorId!)
          : LoginPage(),
    );
  }
}

// ================= LOGIN =================

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController sponsorController = TextEditingController();

  bool mostrarPassword = false;

  // ================= LOGIN =================

  Future<void> login() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": emailController.text,
          "password": passwordController.text,
        }),
      );

      final data = json.decode(response.body);

      if (data['success'] == true && data['user'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(user: data['user']),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Login incorrecto")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión. Intenta de nuevo.")),
      );
    }
  }

  // ================= VALIDAR SPONSOR =================

  Future<void> validarSponsor() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/validate-sponsor'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"codigo": sponsorController.text}),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => RegisterPage(
      sponsorId: data['sponsor']['id'].toString(),
    ),
  ),
);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión. Intenta de nuevo.")),
      );
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("GANACOL")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // EMAIL
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 15),

            // PASSWORD
            TextField(
              controller: passwordController,
              obscureText: !mostrarPassword,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    mostrarPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      mostrarPassword = !mostrarPassword;
                    });
                  },
                ),
              ),
            ),

            SizedBox(height: 20),

            // BOTON LOGIN
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: login,
                child: Text("Ingresar"),
              ),
            ),

            SizedBox(height: 40),

            Divider(),

            SizedBox(height: 20),

            Text(
              "¿Tienes código de invitación?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 15),

            // CODIGO SPONSOR
            TextField(
              controller: sponsorController,
              decoration: InputDecoration(
                labelText: "Código del sponsor",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 15),

            // BOTON VALIDAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: validarSponsor,
                child: Text("Crear cuenta"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= REGISTER =================

class RegisterPage extends StatefulWidget {
  final String sponsorId;

  RegisterPage({required this.sponsorId});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool mostrarPasswordRegister = false;

  TextEditingController nombre = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController telefono = TextEditingController();
  TextEditingController password = TextEditingController();

  Future<void> register() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/register'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "nombre": nombre.text,
          "email": email.text,
          "telefono": telefono.text,
          "password": password.text,
          "sponsor_id": int.parse(widget.sponsorId),
        }),
      );

      final data = json.decode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );

      if (data['success'] == true) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión. Intenta de nuevo.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Registro")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Invitado por ID: ${widget.sponsorId}"),

            SizedBox(height: 15),

            TextField(
              controller: nombre,
              decoration: InputDecoration(labelText: "Nombre"),
            ),

            SizedBox(height: 15),

            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: "Email"),
            ),

            SizedBox(height: 15),

            TextField(
              controller: telefono,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: "Teléfono"),
            ),

            SizedBox(height: 15),

            TextField(
              controller: password,
              obscureText: !mostrarPasswordRegister,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    mostrarPasswordRegister
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      mostrarPasswordRegister = !mostrarPasswordRegister;
                    });
                  },
                ),
              ),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: register,
              child: Text("Registrarme"),
            )
          ],
        ),
      ),
    );
  }
}

// ================= HOME =================

class HomePage extends StatefulWidget {
  final Map user;

  HomePage({required this.user});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List users = [];
  List commissions = [];
  double total = 0;
  double pagoMensual = 0;
  int totalPersonas = 0;
  String proximoCorte = "";

  Future<void> getPlan() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/my-plan/${widget.user['id']}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          pagoMensual = double.parse(data['pago_mensual'].toString());
          totalPersonas = data['total_personas'];

          final hoy = DateTime.now();
          proximoCorte = hoy.day <= 15 ? "15" : "30";
        });
      }
    } catch (e) {
      // Silencioso — se muestra en pantalla con valores en 0
    }
  }

  bool isAdmin() {
    return widget.user['email'] == "quecuriosodia@gmail.com";
  }

  String getUserEmail(id) {
    try {
      var user = users.firstWhere(
        (u) => u['id'].toString() == id.toString(),
      );
      return user['email'];
    } catch (e) {
      return "Desconocido";
    }
  }

  Future<void> loadData() async {
    await getUsers();
    await getCommissions();
    await getTotal();
  }

  Future<void> getUsers() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/users'));

      if (res.statusCode == 200) {
        setState(() {
          users = json.decode(res.body);
        });
      }
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> getCommissions() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/my-commissions/${widget.user['id']}'),
      );

      if (res.statusCode == 200) {
        setState(() {
          commissions = json.decode(res.body);
        });
      }
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> getTotal() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/my-total/${widget.user['id']}'),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          total = double.tryParse(data['total'].toString()) ?? 0;
        });
      }
    } catch (e) {
      // Error silencioso
    }
  }

  @override
  void initState() {
    super.initState();
    loadData();
    getPlan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hola ${widget.user['nombre']}"),
        actions: [
          if (isAdmin())
            IconButton(
              icon: Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminPage()),
                );
              },
            ),

          IconButton(
            icon: Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NetworkPage(
  user: widget.user,
  viewerId: widget.user['id'],
),
                ),
              );
            },
          ),

          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.user),
                ),
              );
            },
          ),

          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Colors.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TOTAL GANADO",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                SizedBox(height: 10),

                // FIX: mostrar 'total' (suma de comisiones), no pagoMensual
                Text(
                  "\$${total.toStringAsFixed(0)} USD",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 10),

                Text(
                  "Plan mensual: \$${pagoMensual.toStringAsFixed(0)} USD",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),

                SizedBox(height: 15),

                Text(
                  "Personas en red: $totalPersonas",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),

                SizedBox(height: 8),

                Text(
                  "Próximo corte: Día $proximoCorte",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: commissions.length,
              itemBuilder: (_, i) {
                return ListTile(
                  title: Text("\$${commissions[i]['monto']}"),
                  subtitle: Text(
                    "De: ${getUserEmail(commissions[i]['from_user_id'])}",
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// ================= ADMIN =================
class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List users = [];
  String search = "";

  Future<void> getUsers() async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/users'));

      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar usuarios")),
      );
    }
  }

  Future<void> activar(int id) async {
    try {
      await http.post(Uri.parse('$BASE_URL/activate/$id'));
      getUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al activar usuario")),
      );
    }
  }

  Future<void> desactivar(int id) async {
    try {
      await http.post(Uri.parse('$BASE_URL/deactivate/$id'));
      getUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al desactivar usuario")),
      );
    }
  }

  Future<void> eliminarUsuario(int id) async {
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Clave de administrador"),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Ingrese la clave",
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancelar"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text("Eliminar"),
              onPressed: () async {
                try {
                  final response = await http.post(
                    Uri.parse('$BASE_URL/delete-user/$id'),
                    headers: {
                      "Content-Type": "application/json",
                    },
                    body: json.encode({
                      "adminPassword": passwordController.text,
                    }),
                  );

                  final data = json.decode(response.body);

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'])),
                  );

                  if (data['success'] == true) {
                    getUsers();
                  }
                } catch (e) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error de conexión")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    getUsers();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = users.where((u) {
      return u['nombre']
              .toString()
              .toLowerCase()
              .contains(search) ||

          u['email']
              .toString()
              .toLowerCase()
              .contains(search) ||

          u['codigo']
              .toString()
              .toLowerCase()
              .contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel"),
      ),

      body: Column(
        children: [

          // BUSCADOR
          Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar por nombre, email o código",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  search = value.toLowerCase();
                });
              },
            ),
          ),

          // LISTA
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,

              itemBuilder: (_, i) {
                var u = filteredUsers[i];

                Color estadoColor = Colors.orange;

                if (u['estado'] == 'activo') {
                  estadoColor = Colors.green;
                }

                if (u['estado'] == 'inactivo') {
                  estadoColor = Colors.red;
                }

                return Card(
                  margin: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  child: ListTile(
                    title: Text(
                      u['nombre'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        SizedBox(height: 5),

                        Text(
                          "Código: ${u['codigo'] ?? 'Sin código'}",
                        ),

                        SizedBox(height: 8),

                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: estadoColor,
                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: Text(
                            u['estado'].toUpperCase(),

                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        if (u['estado'] != 'activo')
                          IconButton(
                            icon: Icon(
                              Icons.check,
                              color: Colors.green,
                            ),
                            onPressed: () => activar(u['id']),
                          ),

                        if (u['estado'] != 'inactivo')
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.red,
                            ),
                            onPressed: () => desactivar(u['id']),
                          ),

                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.black,
                          ),
                          onPressed: () => eliminarUsuario(u['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// ================= PERFIL =================

// FIX: Cambiado a StatefulWidget para poder usar context correctamente
class ProfilePage extends StatefulWidget {
  final Map user;

  ProfilePage({required this.user});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // FIX: Movido aquí desde ProfilePage (StatelessWidget) — ahora tiene acceso
  // correcto a context y widget
  void mostrarCambiarPassword() {
    final actualController = TextEditingController();
    final nuevaController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Cambiar contraseña"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: actualController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Contraseña actual"),
              ),
              SizedBox(height: 15),
              TextField(
                controller: nuevaController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Nueva contraseña"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancelar"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text("Guardar"),
              onPressed: () async {
                try {
                  final response = await http.post(
                    Uri.parse('$BASE_URL/change-password'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'userId': widget.user['id'],
                      'currentPassword': actualController.text,
                      'newPassword': nuevaController.text,
                    }),
                  );

                  final data = json.decode(response.body);

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'])),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error de conexión")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Perfil")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.user['nombre'],
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(widget.user['email']),
            SizedBox(height: 10),
            Text("Código: ${widget.user['codigo']}"),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.lock),
                label: Text("Cambiar contraseña"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: mostrarCambiarPassword,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= RED =================

class NetworkPage extends StatefulWidget {

  final Map user;

  final int viewerId;

  NetworkPage({
    required this.user,
    required this.viewerId,
  });

  @override
  _NetworkPageState createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  List directos = [];
  bool cargando = true;

  Future<void> getNetwork(int userId) async {
    setState(() {
      cargando = true;
    });

    try {
      final res = await http.get(
        Uri.parse(
  '$BASE_URL/my-network/$userId?viewer=${widget.viewerId}',
),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          directos = data['directos'];
          print(data);
          cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        cargando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar la red")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getNetwork(widget.user['id']);
  }

  Widget cajaUsuario(dynamic u) {

  // ================= ESTADO =================

  Color colorEstado = Colors.orange;

  if (u['estado'] == 'activo') {
    colorEstado = Colors.green;
  }

  if (u['estado'] == 'inactivo') {
    colorEstado = Colors.red;
  }

  // ================= NUEVA LOGICA VISUAL =================

  bool generaComision = u['genera_comision'] == true;

  int nivelGenerador = u['nivel_generador'] ?? 0;

  Color borderColor = Colors.transparent;

  double borderWidth = 0;

  List<BoxShadow> sombras = [];

  Widget? iconoSuperior;

  // ================= GENERA COMISION =================

  if (generaComision) {

    borderColor = Colors.amber;

    borderWidth = 3;

    // ================= NIVEL 10 =================

    if (nivelGenerador >= 10) {

      sombras = [
        BoxShadow(
          color: Colors.amber.withOpacity(0.6),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];

      iconoSuperior = Icon(
        Icons.local_fire_department,
        color: Colors.orange,
        size: 20,
      );
    }

    // ================= NIVEL 20 =================

    if (nivelGenerador >= 20) {

      borderColor = Colors.purpleAccent;

      sombras = [
        BoxShadow(
          color: Colors.purpleAccent.withOpacity(0.7),
          blurRadius: 18,
          spreadRadius: 3,
        ),
      ];

      iconoSuperior = Icon(
        Icons.workspace_premium,
        color: Colors.amber,
        size: 22,
      );
    }
  }

  // ================= UI =================

  return GestureDetector(
    onTap: () {
      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => NetworkPage(
      user: u,
      viewerId: widget.viewerId,
    ),
  ),
);
    },

    child: Stack(
      clipBehavior: Clip.none,
      children: [

        // ================= CUADRO =================

        Container(
          width: 100,
          height: 100,

          margin: EdgeInsets.symmetric(horizontal: 8),

          decoration: BoxDecoration(

            color: colorEstado,

            borderRadius: BorderRadius.circular(12),

            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),

            boxShadow: sombras,
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Text(
                "${u['codigo']}",

                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),

              SizedBox(height: 6),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),

                child: Text(
                  u['nombre'],

                  textAlign: TextAlign.center,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ================= ICONO SUPERIOR =================

        if (iconoSuperior != null)
          Positioned(
            top: -10,
            right: -5,
            child: Container(
              padding: EdgeInsets.all(4),

              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),

              child: iconoSuperior,
            ),
          ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Red de ${widget.user['nombre']}"),
      ),
      body: cargando
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(height: 20),

                // USUARIO ACTUAL
                Center(
                  child: Container(
                    width: 120,
                    height: 110,
                    decoration: BoxDecoration(
                      color: widget.user['estado'] == 'activo'
                          ? Colors.green
                          : widget.user['estado'] == 'inactivo'
                              ? Colors.red
                              : Colors.orange,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 5),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${widget.user['codigo']}",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            widget.user['nombre'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 25),

                Icon(Icons.keyboard_arrow_down, size: 35, color: Colors.grey),

                SizedBox(height: 10),

                Text(
                  "Directos",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 20),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...directos.map((u) => cajaUsuario(u)).toList(),
                      ...List.generate(
                        (12 - directos.length).clamp(0, 12),
                        (index) => Container(
                          width: 90,
                          height: 90,
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Center(
                            child: Text(
                              "VACÍO",
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                Text(
                  "Toque un código para bajar en la red",
                  style: TextStyle(color: Colors.grey),
                ),

                // FIX: Botón "Cambiar contraseña" eliminado de NetworkPage
                // — no tiene sentido aquí, pertenece a ProfilePage
              ],
            ),
    );
  }
}