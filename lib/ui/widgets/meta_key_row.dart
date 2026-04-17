import 'package:flutter/material.dart';

class MetaKeyRow extends StatelessWidget {
  const MetaKeyRow({
    super.key,
    required this.keyName,
    required this.onEdit,
    required this.onView,
    required this.onCopy,
    required this.onDelete,
  });

  final String keyName;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              keyName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'view', child: Text('View')),
              const PopupMenuItem(value: 'copy', child: Text('Copy')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent.shade100),
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'view':
                  onView();
                  break;
                case 'copy':
                  onCopy();
                  break;
                case 'delete':
                  onDelete();
                  break;
                default:
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}

