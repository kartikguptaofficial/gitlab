import {
  getDateWithUTC,
  newDateAsLocaleTime,
  nSecondsAfter,
  nSecondsBefore,
  isToday,
} from '~/lib/utils/datetime/date_calculation_utility';
import { useFakeDate } from 'helpers/fake_date';

describe('newDateAsLocaleTime', () => {
  it.each`
    string                        | expected
    ${'2022-03-22'}               | ${new Date('2022-03-22T00:00:00.000Z')}
    ${'2022-03-22T00:00:00.000Z'} | ${new Date('2022-03-22T00:00:00.000Z')}
    ${2022}                       | ${null}
    ${[]}                         | ${null}
    ${{}}                         | ${null}
    ${true}                       | ${null}
    ${null}                       | ${null}
    ${undefined}                  | ${null}
  `('returns $expected given $string', ({ string, expected }) => {
    expect(newDateAsLocaleTime(string)).toEqual(expected);
  });
});

describe('getDateWithUTC', () => {
  it.each`
    date                                    | expected
    ${new Date('2022-03-22T01:23:45.678Z')} | ${new Date('2022-03-22T00:00:00.000Z')}
    ${new Date('1999-12-31T23:59:59.999Z')} | ${new Date('1999-12-31T00:00:00.000Z')}
    ${2022}                                 | ${null}
    ${[]}                                   | ${null}
    ${{}}                                   | ${null}
    ${true}                                 | ${null}
    ${null}                                 | ${null}
    ${undefined}                            | ${null}
  `('returns $expected given $string', ({ date, expected }) => {
    expect(getDateWithUTC(date)).toEqual(expected);
  });
});

describe('nSecondsAfter', () => {
  const start = new Date('2022-03-22T01:23:45.678Z');
  it.each`
    date     | seconds  | expected
    ${start} | ${0}     | ${start}
    ${start} | ${1}     | ${new Date('2022-03-22T01:23:46.678Z')}
    ${start} | ${5}     | ${new Date('2022-03-22T01:23:50.678Z')}
    ${start} | ${60}    | ${new Date('2022-03-22T01:24:45.678Z')}
    ${start} | ${3600}  | ${new Date('2022-03-22T02:23:45.678Z')}
    ${start} | ${86400} | ${new Date('2022-03-23T01:23:45.678Z')}
  `('returns $expected given $string', ({ date, seconds, expected }) => {
    expect(nSecondsAfter(date, seconds)).toEqual(expected);
  });
});

describe('nSecondsBefore', () => {
  const start = new Date('2022-03-22T01:23:45.678Z');
  it.each`
    date     | seconds  | expected
    ${start} | ${0}     | ${start}
    ${start} | ${1}     | ${new Date('2022-03-22T01:23:44.678Z')}
    ${start} | ${5}     | ${new Date('2022-03-22T01:23:40.678Z')}
    ${start} | ${60}    | ${new Date('2022-03-22T01:22:45.678Z')}
    ${start} | ${3600}  | ${new Date('2022-03-22T00:23:45.678Z')}
    ${start} | ${86400} | ${new Date('2022-03-21T01:23:45.678Z')}
  `('returns $expected given $string', ({ date, seconds, expected }) => {
    expect(nSecondsBefore(date, seconds)).toEqual(expected);
  });
});

describe('isToday', () => {
  useFakeDate(2022, 11, 5);

  describe('when date is today', () => {
    it('returns `true`', () => {
      expect(isToday(new Date(2022, 11, 5))).toBe(true);
    });
  });

  describe('when date is not today', () => {
    it('returns `false`', () => {
      expect(isToday(new Date(2022, 11, 6))).toBe(false);
    });
  });
});
