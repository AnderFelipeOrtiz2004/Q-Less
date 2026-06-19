import 'package:flutter/material.dart';

import '../config/legal_terms.dart';

/// Solo lectura — para revisar términos sin aceptar de nuevo.
Future<void> showLegalTermsViewer(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3EC13B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gavel_outlined, color: Color(0xFF3EC13B)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              LegalTerms.title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            LegalTerms.body,
            style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3EC13B)),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// Diálogo obligatorio antes de iniciar sesión con Google.
Future<bool> showLegalTermsDialog(BuildContext context) async {
  var accepted = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3EC13B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Color(0xFF3EC13B)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Antes de continuar',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versión ${LegalTerms.version} — ${LegalTerms.title}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                  Material(
                    color: accepted ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      value: accepted,
                      activeColor: const Color(0xFF3EC13B),
                      onChanged: (value) {
                        setState(() => accepted = value == true);
                      },
                      title: const Text(
                        'He leído y acepto los términos legales.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: accepted ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3EC13B)),
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
