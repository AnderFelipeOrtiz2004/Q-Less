import 'package:flutter/material.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos'),
        backgroundColor: const Color(0xFF3EC13B),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contáctanos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Si tienes dudas o necesitas ayuda, contáctanos por los siguientes medios:',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.email, color: Color(0xFF3EC13B)),
              title: Text('soporte@q-less.com'),
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Color(0xFF3EC13B)),
              title: Text('+54 9 11 1234 5678'),
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: Color(0xFF3EC13B)),
              title: Text('Buenos Aires, Argentina'),
            ),
          ],
        ),
      ),
    );
  }
}
