import { getPaymentStatus } from '../paymentStatus';
import { PaymentStatus } from '../paymentStatus/paymentStatus';

describe('getPaymentStatus', () => {
  it('resolves a success code', () => {
    expect(getPaymentStatus('000.000.000')).toEqual({
      code: '000.000.000',
      description: 'Transaction succeeded',
      status: 'successfully',
    });
  });

  it('resolves a pending code', () => {
    expect(getPaymentStatus('000.200.000').status).toBe('pending');
  });

  it('resolves a rejected code', () => {
    expect(getPaymentStatus('800.100.153').status).toBe('rejected');
  });

  it('resolves a chargeback code', () => {
    expect(getPaymentStatus('000.100.201').status).toBe('Chargeback');
  });

  it('returns an error result for a code that matches no group', () => {
    expect(getPaymentStatus('not-a-real-code')).toEqual({
      code: 'not-a-real-code',
      description: 'This status code is invalid',
      status: 'error',
    });
  });

  it('falls back to the group status for a code that matches a group but has no map entry', () => {
    const result = getPaymentStatus('800.100.999');
    expect(result).toBeDefined();
    expect(result.code).toBe('800.100.999');
    expect(result.status).toBe('rejected');
    expect(typeof result.description).toBe('string');
  });
});

describe('PaymentStatus data map', () => {
  it('every entry is well-formed and keyed by its own code', () => {
    const groupNames = Object.keys(PaymentStatus) as Array<
      keyof typeof PaymentStatus
    >;
    expect(groupNames.length).toBeGreaterThan(0);
    for (const group of groupNames) {
      for (const [code, entry] of Object.entries(PaymentStatus[group])) {
        expect(entry.code).toBe(code);
        expect(typeof entry.description).toBe('string');
        expect(typeof entry.status).toBe('string');
      }
    }
  });
});
