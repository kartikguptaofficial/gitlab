import { initArkoseLabsScript } from 'ee/arkose_labs/init_arkose_labs_script';

jest.mock('lodash/uniqueId', () => (x) => `${x}7`);

const EXPECTED_CALLBACK_NAME = '_initArkoseLabsScript_callback_7';
const TEST_PUBLIC_KEY = 'arkose-labs-public-api-key';
const TEST_DOMAIN = 'client-api.arkoselabs.com';
const MOCK_CLIENT_ERROR_HANDLER = jest.fn();

describe('initArkoseLabsScript', () => {
  let subject;

  const initSubject = () => {
    subject = initArkoseLabsScript({
      publicKey: TEST_PUBLIC_KEY,
      domain: TEST_DOMAIN,
      handleError: MOCK_CLIENT_ERROR_HANDLER,
    });
  };

  const findScriptTags = () => document.querySelectorAll('script');

  afterEach(() => {
    subject = null;
    document.getElementsByTagName('html')[0].innerHTML = '';
  });

  it('sets a global enforcement callback', () => {
    initSubject();

    expect(window[EXPECTED_CALLBACK_NAME]).not.toBe(undefined);
  });

  it('adds ArkoseLabs scripts to the HTML head', () => {
    expect(findScriptTags()).toHaveLength(0);

    initSubject();

    const scriptTag = findScriptTags().item(0);

    expect(scriptTag.getAttribute('type')).toBe('text/javascript');
    expect(scriptTag.getAttribute('src')).toBe(
      `https://${TEST_DOMAIN}/v2/${TEST_PUBLIC_KEY}/api.js`,
    );
    expect(scriptTag.dataset.callback).toBe(EXPECTED_CALLBACK_NAME);
    expect(scriptTag.getAttribute('id')).toBe('arkose-challenge-script');
  });

  it('when callback is called, cleans up the global object and resolves the Promise', () => {
    initSubject();
    const enforcement = 'ArkoseLabsEnforcement';
    window[EXPECTED_CALLBACK_NAME](enforcement);

    expect(window[EXPECTED_CALLBACK_NAME]).toBe(undefined);
    return expect(subject).resolves.toBe(enforcement);
  });

  it('rejects the promise when script fails to load', () => {
    initSubject();

    const scriptTag = findScriptTags().item(0);
    const error = new Error();
    scriptTag.onerror(error);

    return expect(subject).rejects.toThrow(error);
  });

  it('only creates one script tag', () => {
    initSubject();
    initSubject();

    expect(findScriptTags()).toHaveLength(1);
  });
});
