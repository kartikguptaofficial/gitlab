import { commitActionTypes } from '~/ide/constants';
import * as utils from '~/ide/stores/utils';
import { file } from '../helpers';

describe('Multi-file store utils', () => {
  describe('setPageTitle', () => {
    it('sets the document page title', () => {
      utils.setPageTitle('test');

      expect(document.title).toBe('test');
    });
  });

  describe('setPageTitleForFile', () => {
    it('sets the document page title for the file passed', () => {
      const f = {
        path: 'README.md',
      };

      const state = {
        currentBranchId: 'main',
        currentProjectId: 'test/test',
      };

      utils.setPageTitleForFile(state, f);

      expect(document.title).toBe('README.md · main · test/test · GitLab');
    });
  });

  describe('createCommitPayload', () => {
    it('returns API payload', () => {
      const state = {
        commitMessage: 'commit message',
      };
      const rootState = {
        stagedFiles: [
          {
            ...file('staged'),
            path: 'staged',
            content: 'updated file content',
            lastCommitSha: '123456789',
          },
          {
            ...file('newFile'),
            path: 'added',
            tempFile: true,
            content: 'new file content',
            rawPath: 'blob:https://gitlab.com/048c7ac1-98de-4a37-ab1b-0206d0ea7e1b',
            lastCommitSha: '123456789',
          },
          { ...file('deletedFile'), path: 'deletedFile', deleted: true },
          { ...file('renamedFile'), path: 'renamedFile', prevPath: 'prevPath' },
        ],
        currentBranchId: 'main',
      };
      const payload = utils.createCommitPayload({
        branch: 'main',
        newBranch: false,
        state,
        rootState,
        getters: {},
      });

      expect(payload).toEqual({
        branch: 'main',
        commit_message: 'commit message',
        actions: [
          {
            action: commitActionTypes.update,
            file_path: 'staged',
            content: 'updated file content',
            encoding: 'text',
            last_commit_id: '123456789',
            previous_path: undefined,
          },
          {
            action: commitActionTypes.create,
            file_path: 'added',
            // atob("new file content")
            content: 'bmV3IGZpbGUgY29udGVudA==',
            encoding: 'base64',
            last_commit_id: '123456789',
            previous_path: undefined,
          },
          {
            action: commitActionTypes.delete,
            file_path: 'deletedFile',
            content: undefined,
            encoding: 'text',
            last_commit_id: undefined,
            previous_path: undefined,
          },
          {
            action: commitActionTypes.move,
            file_path: 'renamedFile',
            content: null,
            encoding: 'text',
            last_commit_id: undefined,
            previous_path: 'prevPath',
          },
        ],
        start_sha: undefined,
      });
    });

    it('uses prebuilt commit message when commit message is empty', () => {
      const rootState = {
        stagedFiles: [
          {
            ...file('staged'),
            path: 'staged',
            content: 'updated file content',
            lastCommitSha: '123456789',
          },
          {
            ...file('newFile'),
            path: 'added',
            tempFile: true,
            content: 'new file content',
            rawPath: 'blob:https://gitlab.com/048c7ac1-98de-4a37-ab1b-0206d0ea7e1b',
            lastCommitSha: '123456789',
          },
        ],
        currentBranchId: 'main',
      };
      const payload = utils.createCommitPayload({
        branch: 'main',
        newBranch: false,
        state: {},
        rootState,
        getters: {
          preBuiltCommitMessage: 'prebuilt test commit message',
        },
      });

      expect(payload).toEqual({
        branch: 'main',
        commit_message: 'prebuilt test commit message',
        actions: [
          {
            action: commitActionTypes.update,
            file_path: 'staged',
            content: 'updated file content',
            encoding: 'text',
            last_commit_id: '123456789',
            previous_path: undefined,
          },
          {
            action: commitActionTypes.create,
            file_path: 'added',
            // atob("new file content")
            content: 'bmV3IGZpbGUgY29udGVudA==',
            encoding: 'base64',
            last_commit_id: '123456789',
            previous_path: undefined,
          },
        ],
        start_sha: undefined,
      });
    });
  });

  describe('commitActionForFile', () => {
    it('returns deleted for deleted file', () => {
      expect(
        utils.commitActionForFile({
          deleted: true,
        }),
      ).toBe(commitActionTypes.delete);
    });

    it('returns create for tempFile', () => {
      expect(
        utils.commitActionForFile({
          tempFile: true,
        }),
      ).toBe(commitActionTypes.create);
    });

    it('returns move for moved file', () => {
      expect(
        utils.commitActionForFile({
          prevPath: 'test',
        }),
      ).toBe(commitActionTypes.move);
    });

    it('returns update by default', () => {
      expect(utils.commitActionForFile({})).toBe(commitActionTypes.update);
    });
  });

  describe('getCommitFiles', () => {
    it('filters out folders from the list', () => {
      const files = [
        {
          path: 'a',
          type: 'blob',
          deleted: true,
        },
        {
          path: 'c',
          type: 'tree',
          deleted: true,
        },
        {
          path: 'c/d',
          type: 'blob',
          deleted: true,
        },
      ];

      const flattendFiles = utils.getCommitFiles(files);

      expect(flattendFiles).toEqual([
        {
          path: 'a',
          type: 'blob',
          deleted: true,
        },
        {
          path: 'c/d',
          type: 'blob',
          deleted: true,
        },
      ]);
    });
  });

  describe('mergeTrees', () => {
    let fromTree;
    let toTree;

    beforeEach(() => {
      fromTree = [file('foo')];
      toTree = [file('bar')];
    });

    it('merges simple trees with sorting the result', () => {
      toTree = [file('beta'), file('alpha'), file('gamma')];
      const res = utils.mergeTrees(fromTree, toTree);

      expect(res.length).toEqual(4);
      expect(res[0].name).toEqual('alpha');
      expect(res[1].name).toEqual('beta');
      expect(res[2].name).toEqual('foo');
      expect(res[3].name).toEqual('gamma');
      expect(res[2]).toBe(fromTree[0]);
    });

    it('handles edge cases', () => {
      expect(utils.mergeTrees({}, []).length).toEqual(0);

      let res = utils.mergeTrees({}, toTree);

      expect(res.length).toEqual(1);
      expect(res[0].name).toEqual('bar');

      res = utils.mergeTrees(fromTree, []);

      expect(res.length).toEqual(1);
      expect(res[0].name).toEqual('foo');
      expect(res[0]).toBe(fromTree[0]);
    });

    it('merges simple trees without producing duplicates', () => {
      toTree.push(file('foo'));

      const res = utils.mergeTrees(fromTree, toTree);

      expect(res.length).toEqual(2);
      expect(res[0].name).toEqual('bar');
      expect(res[1].name).toEqual('foo');
      expect(res[1]).not.toBe(fromTree[0]);
    });

    it('merges nested tree into the main one without duplicates', () => {
      fromTree[0].tree.push({
        ...file('alpha'),
        path: 'foo/alpha',
        tree: [{ ...file('beta.md'), path: 'foo/alpha/beta.md' }],
      });

      toTree.push({
        ...file('foo'),
        tree: [
          {
            ...file('alpha'),
            path: 'foo/alpha',
            tree: [{ ...file('gamma.md'), path: 'foo/alpha/gamma.md' }],
          },
        ],
      });

      const res = utils.mergeTrees(fromTree, toTree);

      expect(res.length).toEqual(2);
      expect(res[1].name).toEqual('foo');

      const finalBranch = res[1].tree[0].tree;

      expect(finalBranch.length).toEqual(2);
      expect(finalBranch[0].name).toEqual('beta.md');
      expect(finalBranch[1].name).toEqual('gamma.md');
    });

    it('marks correct folders as opened as the parsing goes on', () => {
      fromTree[0].tree.push({
        ...file('alpha'),
        path: 'foo/alpha',
        tree: [{ ...file('beta.md'), path: 'foo/alpha/beta.md' }],
      });

      toTree.push({
        ...file('foo'),
        tree: [
          {
            ...file('alpha'),
            path: 'foo/alpha',
            tree: [{ ...file('gamma.md'), path: 'foo/alpha/gamma.md' }],
          },
        ],
      });

      const res = utils.mergeTrees(fromTree, toTree);

      expect(res[1].name).toEqual('foo');
      expect(res[1].opened).toEqual(true);

      expect(res[1].tree[0].name).toEqual('alpha');
      expect(res[1].tree[0].opened).toEqual(true);
    });
  });

  describe('swapInStateArray', () => {
    let localState;

    beforeEach(() => {
      localState = [];
    });

    it('swaps existing entry with a new one', () => {
      const file1 = { ...file('old'), key: 'foo' };
      const file2 = file('new');
      const arr = [file1];

      Object.assign(localState, {
        dummyArray: arr,
        entries: {
          new: file2,
        },
      });

      utils.swapInStateArray(localState, 'dummyArray', 'foo', 'new');

      expect(localState.dummyArray.length).toBe(1);
      expect(localState.dummyArray[0]).toBe(file2);
    });

    it('does not add an item if it does not exist yet in array', () => {
      const file1 = file('file');
      Object.assign(localState, {
        dummyArray: [],
        entries: {
          file: file1,
        },
      });

      utils.swapInStateArray(localState, 'dummyArray', 'foo', 'file');

      expect(localState.dummyArray.length).toBe(0);
    });
  });

  describe('swapInParentTreeWithSorting', () => {
    let localState;
    let branchInfo;
    const currentProjectId = '123-foo';
    const currentBranchId = 'main';

    beforeEach(() => {
      localState = {
        currentBranchId,
        currentProjectId,
        trees: {
          [`${currentProjectId}/${currentBranchId}`]: {
            tree: [],
          },
        },
        entries: {
          oldPath: file('oldPath', 'oldPath', 'blob'),
          newPath: file('newPath', 'newPath', 'blob'),
          parentPath: file('parentPath', 'parentPath', 'tree'),
        },
      };
      branchInfo = localState.trees[`${currentProjectId}/${currentBranchId}`];
    });

    it('does not change tree if newPath is not supplied', () => {
      branchInfo.tree = [localState.entries.oldPath];

      utils.swapInParentTreeWithSorting(localState, 'oldPath', undefined, undefined);

      expect(branchInfo.tree).toEqual([localState.entries.oldPath]);
    });

    describe('oldPath to replace is not defined: simple addition to tree', () => {
      it('adds to tree on the state if there is no parent for the entry', () => {
        expect(branchInfo.tree.length).toBe(0);

        utils.swapInParentTreeWithSorting(localState, undefined, 'oldPath', undefined);

        expect(branchInfo.tree.length).toBe(1);
        expect(branchInfo.tree[0].name).toBe('oldPath');

        utils.swapInParentTreeWithSorting(localState, undefined, 'newPath', undefined);

        expect(branchInfo.tree.length).toBe(2);
        expect(branchInfo.tree).toEqual([
          expect.objectContaining({
            name: 'newPath',
          }),
          expect.objectContaining({
            name: 'oldPath',
          }),
        ]);
      });

      it('adds to parent tree if it is supplied', () => {
        utils.swapInParentTreeWithSorting(localState, undefined, 'newPath', 'parentPath');

        expect(localState.entries.parentPath.tree.length).toBe(1);
        expect(localState.entries.parentPath.tree).toEqual([
          expect.objectContaining({
            name: 'newPath',
          }),
        ]);

        localState.entries.parentPath.tree = [localState.entries.oldPath];

        utils.swapInParentTreeWithSorting(localState, undefined, 'newPath', 'parentPath');

        expect(localState.entries.parentPath.tree.length).toBe(2);
        expect(localState.entries.parentPath.tree).toEqual([
          expect.objectContaining({
            name: 'newPath',
          }),
          expect.objectContaining({
            name: 'oldPath',
          }),
        ]);
      });
    });

    describe('swapping of the items', () => {
      it('swaps entries if both paths are supplied', () => {
        branchInfo.tree = [localState.entries.oldPath];

        utils.swapInParentTreeWithSorting(localState, localState.entries.oldPath.key, 'newPath');

        expect(branchInfo.tree).toEqual([
          expect.objectContaining({
            name: 'newPath',
          }),
        ]);

        utils.swapInParentTreeWithSorting(localState, localState.entries.newPath.key, 'oldPath');

        expect(branchInfo.tree).toEqual([
          expect.objectContaining({
            name: 'oldPath',
          }),
        ]);
      });

      it('sorts tree after swapping the entries', () => {
        const alpha = file('alpha', 'alpha', 'blob');
        const beta = file('beta', 'beta', 'blob');
        const gamma = file('gamma', 'gamma', 'blob');
        const theta = file('theta', 'theta', 'blob');
        localState.entries = {
          alpha,
          beta,
          gamma,
          theta,
        };

        branchInfo.tree = [alpha, beta, gamma];

        utils.swapInParentTreeWithSorting(localState, alpha.key, 'theta');

        expect(branchInfo.tree).toEqual([
          expect.objectContaining({
            name: 'beta',
          }),
          expect.objectContaining({
            name: 'gamma',
          }),
          expect.objectContaining({
            name: 'theta',
          }),
        ]);

        utils.swapInParentTreeWithSorting(localState, gamma.key, 'alpha');

        expect(branchInfo.tree).toEqual([
          expect.objectContaining({
            name: 'alpha',
          }),
          expect.objectContaining({
            name: 'beta',
          }),
          expect.objectContaining({
            name: 'theta',
          }),
        ]);

        utils.swapInParentTreeWithSorting(localState, beta.key, 'gamma');

        expect(branchInfo.tree).toEqual([
          expect.objectContaining({
            name: 'alpha',
          }),
          expect.objectContaining({
            name: 'gamma',
          }),
          expect.objectContaining({
            name: 'theta',
          }),
        ]);
      });
    });
  });

  describe('cleanTrailingSlash', () => {
    [
      {
        input: '',
        output: '',
      },
      {
        input: 'abc',
        output: 'abc',
      },
      {
        input: 'abc/',
        output: 'abc',
      },
      {
        input: 'abc/def',
        output: 'abc/def',
      },
      {
        input: 'abc/def/',
        output: 'abc/def',
      },
    ].forEach(({ input, output }) => {
      it(`cleans trailing slash from string "${input}"`, () => {
        expect(utils.cleanTrailingSlash(input)).toEqual(output);
      });
    });
  });

  describe('pathsAreEqual', () => {
    [
      {
        args: ['abc', 'abc'],
        output: true,
      },
      {
        args: ['abc', 'def'],
        output: false,
      },
      {
        args: ['abc/', 'abc'],
        output: true,
      },
      {
        args: ['abc/abc', 'abc'],
        output: false,
      },
      {
        args: ['/', ''],
        output: true,
      },
      {
        args: ['', '/'],
        output: true,
      },
      {
        args: [false, '/'],
        output: true,
      },
    ].forEach(({ args, output }) => {
      it(`cleans and tests equality (${JSON.stringify(args)})`, () => {
        expect(utils.pathsAreEqual(...args)).toEqual(output);
      });
    });
  });

  describe('extractMarkdownImagesFromEntries', () => {
    let mdFile;
    let entries;

    beforeEach(() => {
      const img = { content: 'png-gibberish', rawPath: 'blob:1234' };
      mdFile = { path: 'path/to/some/directory/myfile.md' };
      entries = {
        // invalid (or lack of) extensions are also supported as long as there's
        // a real image inside and can go into an <img> tag's `src` and the browser
        // can render it
        img,
        'img.js': img,
        'img.png': img,
        'img.with.many.dots.png': img,
        'path/to/img.gif': img,
        'path/to/some/img.jpg': img,
        'path/to/some/img 1/img.png': img,
        'path/to/some/directory/img.png': img,
        'path/to/some/directory/img 1.png': img,
      };
    });

    it.each`
      markdownBefore                          | ext       | imgAlt           | imgTitle
      ${'* ![img](/img)'}                     | ${'jpeg'} | ${'img'}         | ${undefined}
      ${'* ![img](/img.js)'}                  | ${'js'}   | ${'img'}         | ${undefined}
      ${'* ![img](img.png)'}                  | ${'png'}  | ${'img'}         | ${undefined}
      ${'* ![img](./img.png)'}                | ${'png'}  | ${'img'}         | ${undefined}
      ${'* ![with spaces](../img 1/img.png)'} | ${'png'}  | ${'with spaces'} | ${undefined}
      ${'* ![img](../../img.gif " title ")'}  | ${'gif'}  | ${'img'}         | ${' title '}
      ${'* ![img](../img.jpg)'}               | ${'jpg'}  | ${'img'}         | ${undefined}
      ${'* ![img](/img.png "title")'}         | ${'png'}  | ${'img'}         | ${'title'}
      ${'* ![img](/img.with.many.dots.png)'}  | ${'png'}  | ${'img'}         | ${undefined}
      ${'* ![img](img 1.png)'}                | ${'png'}  | ${'img'}         | ${undefined}
      ${'* ![img](img.png "title here")'}     | ${'png'}  | ${'img'}         | ${'title here'}
    `(
      'correctly transforms markdown with uncommitted images: $markdownBefore',
      ({ markdownBefore, imgAlt, imgTitle }) => {
        mdFile.content = markdownBefore;

        expect(utils.extractMarkdownImagesFromEntries(mdFile, entries)).toEqual({
          content: '* {{gl_md_img_1}}',
          images: {
            '{{gl_md_img_1}}': {
              src: 'blob:1234',
              alt: imgAlt,
              title: imgTitle,
            },
          },
        });
      },
    );

    it.each`
      markdown
      ${'* ![img](i.png)'}
      ${'* ![img](img.png invalid title)'}
      ${'* ![img](img.png "incorrect" "markdown")'}
      ${'* ![img](https://gitlab.com/logo.png)'}
      ${'* ![img](https://gitlab.com/some/deep/nested/path/logo.png)'}
    `("doesn't touch invalid or non-existant images in markdown: $markdown", ({ markdown }) => {
      mdFile.content = markdown;

      expect(utils.extractMarkdownImagesFromEntries(mdFile, entries)).toEqual({
        content: markdown,
        images: {},
      });
    });
  });
});
