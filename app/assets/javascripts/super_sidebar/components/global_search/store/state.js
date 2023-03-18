const createState = ({
  searchPath,
  issuesPath,
  mrPath,
  autocompletePath,
  searchContext,
  search,
}) => ({
  searchPath,
  issuesPath,
  mrPath,
  autocompletePath,
  searchContext,
  search,
  autocompleteOptions: [],
  autocompleteError: false,
  loading: false,
});
export default createState;
