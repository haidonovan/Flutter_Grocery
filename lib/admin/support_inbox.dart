import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';

class SupportInboxPage extends StatelessWidget {
  const SupportInboxPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.supportMessages.isEmpty) {
          return const Center(child: Text('No support messages yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: store.supportMessages.length,
          itemBuilder: (context, index) {
            final msg = store.supportMessages[index];
            return Card(
              child: ListTile(
                leading: Icon(
                  msg.isResolved
                      ? Icons.check_circle_outline
                      : Icons.support_agent,
                ),
                title: Text(msg.userEmail),
                subtitle: Text(msg.message),
                trailing: Switch(
                  value: msg.isResolved,
                  onChanged: (value) {
                    store.resolveSupportMessage(msg.id, value);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
