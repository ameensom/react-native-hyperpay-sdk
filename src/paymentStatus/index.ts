import { groups } from './groups';
import type { PaymentStatus as PaymentStatusType } from '../../lib/typescript/PaymentStatus';
import { PaymentStatus } from './paymentStatus';

export const getPaymentStatus = (code: string): PaymentStatusType => {
  const selectedGroup = groups.find((group) => group.reg.test(code));
  if (selectedGroup) {
    // Codes can match a group's regex range without having a documented
    // entry (e.g. codes HyperPay added after this map was generated) —
    // classify them by the group they fall in.
    return (
      PaymentStatus[selectedGroup.group][code] ?? {
        code,
        description: `Undocumented result code (${selectedGroup.group})`,
        status: selectedGroup.status,
      }
    );
  }
  return {
    code,
    description: 'This status code is invalid',
    status: 'error',
  };
};
