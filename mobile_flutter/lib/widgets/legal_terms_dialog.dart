import 'package:flutter/material.dart';

import '../config/legal_terms.dart';

/// Diálogo obligatorio antes de registrar cuenta y enviar código Gmail.
Future<bool> showLegalTermsDialog(BuildContext context) async {
  var accepted = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(LegalTerms.title),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Debes leer y aceptar los términos legales antes de crear tu cuenta y recibir el código en Gmail.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        LegalTerms.body,
                        style: const TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: (value) {
                      setState(() => accepted = value == true);
                    },
                    title: const Text(
                      'He leído y acepto los Términos y la Política de Privacidad de Q-LESS.',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No acepto'),
              ),
              FilledButton(
                onPressed: accepted ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3EC13B),
                ),
                child: const Text('Acepto y continuar'),
              ),
            ],
          );
        },
      );
    },
  );

  return result == true;
}
