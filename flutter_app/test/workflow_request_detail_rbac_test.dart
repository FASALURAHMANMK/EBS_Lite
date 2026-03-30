import 'package:ebs_lite/features/auth/controllers/auth_permissions_provider.dart';
import 'package:ebs_lite/features/workflow/data/workflow_repository.dart';
import 'package:ebs_lite/features/workflow/presentation/pages/workflow_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required List<String> permissions}) {
  return ProviderScope(
    overrides: [
      authPermissionsProvider.overrideWithValue(permissions),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('WorkflowRequestDetailPage disables actions without permission',
      (tester) async {
    const req = WorkflowRequestDto(
      approvalId: 1,
      locationId: null,
      module: 'PURCHASES',
      entityType: 'PURCHASE_ORDER',
      entityId: 99,
      actionType: 'APPROVE_PURCHASE_ORDER',
      title: 'Approve purchase order PO-0001',
      summary: 'Supplier ACME • total 100.00',
      requestReason: null,
      status: 'PENDING',
      priority: 'HIGH',
      approverRoleId: 2,
      approverRoleName: 'Manager',
      payload: {},
      resultSnapshot: {},
      dueAt: null,
      isOverdue: false,
      escalationLevel: 0,
      createdBy: 5,
      createdByName: 'Requester',
      updatedBy: null,
      approvedBy: null,
      approvedByName: null,
      approvedAt: null,
      decisionReason: null,
      createdAt: null,
      updatedAt: null,
      events: [],
    );

    await tester.pumpWidget(
      _wrap(
        WorkflowRequestDetailPage(
          approvalId: 1,
          initialRequest: req,
        ),
        permissions: ['VIEW_WORKFLOWS'],
      ),
    );

    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    final rejectButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Reject'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    final approveButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Approve'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

    expect(rejectButton.onPressed, isNull);
    expect(approveButton.onPressed, isNull);
  });
}
