export const mockAbuseReports = [
  {
    category: 'spam',
    createdAt: '2018-10-03T05:46:38.977Z',
    updatedAt: '2022-12-07T06:45:39.977Z',
    reporter: { name: 'Ms. Admin' },
    reportedUser: { name: 'Mr. Abuser', createdAt: '2017-09-01T05:46:38.977Z' },
    reportedUserPath: '/mr_abuser',
    reporterPath: '/admin',
    userBlocked: false,
    blockUserPath: '/block/user/mr_abuser/path',
    removeUserAndReportPath: '/remove/user/mr_abuser/and/report/path',
    removeReportPath: '/remove/report/path',
    message: 'message 1',
  },
  {
    category: 'phishing',
    createdAt: '2018-10-03T05:46:38.977Z',
    updatedAt: '2022-12-07T06:45:39.977Z',
    reporter: { name: 'Ms. Reporter' },
    reportedUser: { name: 'Mr. Phisher', createdAt: '2016-09-01T05:46:38.977Z' },
    reportedUserPath: '/mr_phisher',
    reporterPath: '/admin',
    userBlocked: false,
    blockUserPath: '/block/user/mr_phisher/path',
    removeUserAndReportPath: '/remove/user/mr_phisher/and/report/path',
    removeReportPath: '/remove/report/path',
    message: 'message 2',
  },
];
