import test from 'node:test';
import assert from 'node:assert/strict';

function formatVnd(amount) {
  const n = Math.trunc(Number(amount) || 0);
  const abs = Math.abs(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${n < 0 ? '-' : ''}${abs}đ`;
}

function calculateRentalDays(startDate, endDate) {
  const [sy, sm, sd] = startDate.split('-').map(Number);
  const [ey, em, ed] = endDate.split('-').map(Number);
  const s = Date.UTC(sy, sm - 1, sd);
  const e = Date.UTC(ey, em - 1, ed);
  if (e < s) return 0;
  return Math.floor((e - s) / 86400000) + 1;
}

test('formatVnd formats integer VND with dot separators', () => {
  assert.equal(formatVnd(0), '0đ');
  assert.equal(formatVnd(1000), '1.000đ');
  assert.equal(formatVnd(50000), '50.000đ');
  assert.equal(formatVnd(401000), '401.000đ');
  assert.equal(formatVnd(99000), '99.000đ');
});

test('calculateRentalDays includes both start and end dates', () => {
  assert.equal(calculateRentalDays('2027-03-05', '2027-03-05'), 1);
  assert.equal(calculateRentalDays('2027-03-05', '2027-03-06'), 2);
});
