import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../utils/csv_export.dart';

class SupportInboxPage extends StatefulWidget {
  const SupportInboxPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<SupportInboxPage> createState() => _SupportInboxPageState();
}

class _SupportInboxPageState extends State<SupportInboxPage> {
  String _query = '';
  String _status = 'All';
  String _sort = 'Newest';
  DateTimeRange? _dateRange;
  final Set<int> _busyTicketIds = <int>{};

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  List<SupportTicket> _filteredTickets(List<SupportTicket> tickets) {
    final query = _query.trim().toLowerCase();
    final filtered = tickets.where((ticket) {
      if (_status != 'All' && ticket.status != _status) {
        return false;
      }
      if (_dateRange != null) {
        if (ticket.createdAt.isBefore(_dateRange!.start) ||
            ticket.createdAt.isAfter(
              _dateRange!.end.add(const Duration(days: 1)),
            )) {
          return false;
        }
      }
      if (query.isEmpty) {
        return true;
      }
      return ticket.userEmail.toLowerCase().contains(query) ||
          ticket.subject.toLowerCase().contains(query) ||
          ticket.message.toLowerCase().contains(query) ||
          ticket.messages.any(
            (message) => message.message.toLowerCase().contains(query),
          ) ||
          (ticket.adminReply ?? '').toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case 'Oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Status':
        filtered.sort((a, b) => a.status.compareTo(b.status));
        break;
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  Future<void> _exportTickets(List<SupportTicket> tickets) async {
    final rows = <List<String>>[
      ['Ticket ID', 'Customer', 'Subject', 'Status', 'Created At', 'Messages'],
      ...tickets.map(
        (ticket) => [
          ticket.id.toString(),
          ticket.userEmail,
          ticket.subject,
          ticket.status,
          ticket.createdAt.toIso8601String(),
          ticket.messages
              .map((message) => '${message.userRole}: ${message.message}')
              .join(' | '),
        ],
      ),
    ];
    final success = await exportCsv('support_export.csv', buildCsv(rows));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Support CSV downloaded.'
              : 'CSV export is available on web builds.',
        ),
      ),
    );
  }

  Future<void> _runTicketAction(
    int ticketId,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_busyTicketIds.contains(ticketId)) {
      return;
    }

    setState(() => _busyTicketIds.add(ticketId));
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busyTicketIds.remove(ticketId));
      }
    }
  }

  Future<void> _replyToTicket(SupportTicket ticket) async {
    final controller = TextEditingController(text: ticket.adminReply ?? '');
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to ticket'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type your reply',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send reply'),
          ),
        ],
      ),
    );
    if (reply == null || reply.length < 3) {
      return;
    }

    await _runTicketAction(
      ticket.id,
      () => widget.store.replySupportTicket(ticket.id, reply),
      successMessage: 'Reply sent to ${ticket.userEmail}.',
    );
  }

  Future<void> _closeTicket(SupportTicket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close ticket?'),
        content: Text(
          'Close "${ticket.subject}" for ${ticket.userEmail}? The client will no longer be able to reply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close ticket'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _runTicketAction(
      ticket.id,
      () => widget.store.closeSupportTicket(ticket.id),
      successMessage: 'Ticket closed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final tickets = _filteredTickets(widget.store.supportTickets);
        final scheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final search = TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customer, subject, message',
                      prefixIcon: Icon(Icons.search, color: scheme.primary),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  );

                  final status = DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All status')),
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'answered',
                        child: Text('Answered'),
                      ),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  );

                  final sort = DropdownButtonFormField<String>(
                    initialValue: _sort,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                      DropdownMenuItem(value: 'Status', child: Text('Status')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sort = value);
                      }
                    },
                  );

                  final dateText = _dateRange == null
                      ? 'Date range'
                      : '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}';

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: 10),
                        status,
                        const SizedBox(height: 10),
                        sort,
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.date_range),
                              label: Text(dateText),
                            ),
                            if (_dateRange != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _dateRange = null),
                                child: const Text('Clear'),
                              ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: status),
                          const SizedBox(width: 10),
                          Expanded(child: sort),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(dateText),
                          ),
                          if (_dateRange != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _dateRange = null),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Text(
                    '${tickets.length} ticket${tickets.length == 1 ? '' : 's'}',
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _exportTickets(tickets),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? const Center(
                      child: Text('No support tickets for this filter.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        ticket.status == 'closed'
                                            ? Icons.check_circle_outline
                                            : Icons.support_agent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ticket.userEmail,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(ticket.subject),
                                        ],
                                      ),
                                    ),
                                    _busyTicketIds.contains(ticket.id)
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'reply') {
                                                await _replyToTicket(ticket);
                                              } else if (value == 'close') {
                                                await _closeTicket(ticket);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'reply',
                                                child: Text('Reply'),
                                              ),
                                              PopupMenuItem(
                                                value: 'close',
                                                enabled:
                                                    ticket.status != 'closed',
                                                child:
                                                    const Text('Close ticket'),
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...ticket.messages.map(
                                  (message) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: message.userRole == 'admin'
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer
                                                  .withValues(alpha: 0.6)
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                                  .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.userRole == 'admin'
                                                ? 'Admin'
                                                : message.userEmail,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(message.message),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
