import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 🔥 CAMBIA ESTA IP SI USAS CELULAR
const BASE_URL = "http://127.0.0.1:3000";

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

  Future<void> login() async {
    final response = await http.post(
      Uri.parse('$BASE_URL/login'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "email": emailController.text,
        "password": passwordController.text,
      }),
    );

    final data = json.decode(response.body);

    if (data['user'] != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(user: data['user']),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login incorrecto")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: Text("Ingresar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RegisterPage(sponsorId: "1")),
                );
              },
              child: Text("Crear cuenta"),
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
  TextEditingController nombre = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController telefono = TextEditingController();
  TextEditingController password = TextEditingController();

  Future<void> register() async {
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

    Navigator.pop(context);
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

            TextField(
              controller: nombre,
              decoration: InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: email,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: telefono,
              decoration: InputDecoration(labelText: "Teléfono"),
            ),
            TextField(
              controller: password,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
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
    final res = await http.get(Uri.parse('$BASE_URL/users'));
    if (res.statusCode == 200) {
      setState(() {
        users = json.decode(res.body);
      });
    }
  }

  Future<void> getCommissions() async {
    final res = await http.get(
      Uri.parse('$BASE_URL/my-commissions/${widget.user['id']}'),
    );
    if (res.statusCode == 200) {
      setState(() {
        commissions = json.decode(res.body);
      });
    }
  }

  Future<void> getTotal() async {
    final res = await http.get(
      Uri.parse('$BASE_URL/my-total/${widget.user['id']}'),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        total = double.tryParse(data['total'].toString()) ?? 0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadData();
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
                    builder: (_) => NetworkPage(user: widget.user)),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfilePage(user: widget.user)),
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
              children: [
                Text("TOTAL GANADO",
                    style: TextStyle(color: Colors.white)),
                SizedBox(height: 10),
                Text("\$${total.toStringAsFixed(2)}",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
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
                      "De: ${getUserEmail(commissions[i]['from_user_id'])}"),
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

  Future<void> getUsers() async {
    final response = await http.get(Uri.parse('$BASE_URL/users'));
    if (response.statusCode == 200) {
      setState(() {
        users = json.decode(response.body);
      });
    }
  }

  Future<void> activar(int id) async {
    await http.post(Uri.parse('$BASE_URL/activate/$id'));
    getUsers();
  }

  Future<void> desactivar(int id) async {
    await http.post(Uri.parse('$BASE_URL/deactivate/$id'));
    getUsers();
  }

  @override
  void initState() {
    super.initState();
    getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Panel")),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (_, i) {
          var u = users[i];
          return ListTile(
            title: Text(u['nombre']),
            subtitle: Text("Código: ${u['codigo']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () => activar(u['id'])),
                IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () => desactivar(u['id'])),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================= PERFIL =================
class ProfilePage extends StatelessWidget {
  final Map user;

  ProfilePage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Perfil")),
      body: Column(
        children: [
          Text(user['nombre']),
          Text(user['email']),
          Text("Código: ${user['codigo']}"),
        ],
      ),
    );
  }
}

// ================= RED =================
class NetworkPage extends StatefulWidget {
  final Map user;

  NetworkPage({required this.user});

  @override
  _NetworkPageState createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  List directos = [];

  Future<void> getNetwork() async {
    final res = await http.get(
      Uri.parse('$BASE_URL/my-network/${widget.user['id']}'),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        directos = data['directos'];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getNetwork();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mi Red")),
      body: ListView(
        children: directos
            .map((u) => ListTile(
                  title: Text(u['nombre']),
                  subtitle: Text("Código: ${u['codigo']}"),
                ))
            .toList(),
      ),
    );
  }
}