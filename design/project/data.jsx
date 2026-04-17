// StackSpeak — content

const WORDS_TODAY = [
  {
    id: 'idempotent',
    word: 'idempotent',
    pos: 'adjective',
    ipa: 'eye-DEM-po-tent',
    level: 'L2 · Fundamentals',
    tags: ['API', 'HTTP', 'Semantics'],
    short: 'An operation that produces the same result no matter how many times it runs.',
    long: 'A property of certain operations where applying them multiple times has the same effect as applying them once. Critical for safe retries in distributed systems and HTTP methods like PUT and DELETE.',
    etymology: 'from Latin idem (“same”) + potent (“power”) — coined 1870 in algebra.',
    example: {
      lang: 'http',
      code: 'PUT /users/42\n{ "name": "Ada" }\n\n// Running this 1× or 100× → same final state.',
    },
    sentence: 'The retry logic is safe because the endpoint is idempotent.',
  },
  {
    id: 'quorum',
    word: 'quorum',
    pos: 'noun',
    ipa: 'KWOR-um',
    level: 'L3 · Distributed systems',
    tags: ['Consensus', 'Replication'],
    short: 'The minimum number of nodes that must agree for a decision to be valid.',
    long: 'In distributed systems, the smallest subset of participants required to reach agreement. A write quorum plus a read quorum that overlap guarantees strong consistency.',
    etymology: 'Latin — “of whom,” from a formal invitation; adopted into parliamentary use.',
    example: {
      lang: 'yaml',
      code: 'replicas: 5\nwrite_quorum: 3\nread_quorum: 3\n# W + R > N  →  consistent reads',
    },
    sentence: 'We lost quorum when the third replica went down.',
  },
  {
    id: 'backpressure',
    word: 'backpressure',
    pos: 'noun',
    ipa: 'BAK-presh-er',
    level: 'L2 · Systems',
    tags: ['Streams', 'Concurrency'],
    short: 'A signal from a slow consumer telling a fast producer to slow down.',
    long: 'The mechanism by which a downstream component pushes resistance upstream so that producers do not overwhelm consumers. Essential in reactive streams, message queues, and network protocols.',
    etymology: 'from plumbing — pressure that flows against the intended direction.',
    example: {
      lang: 'ts',
      code: 'stream.pipe(consumer, {\n  highWaterMark: 16,\n  backpressure: true,\n});',
    },
    sentence: 'Without backpressure, the producer will exhaust memory.',
  },
  {
    id: 'monad',
    word: 'monad',
    pos: 'noun',
    ipa: 'MON-ad',
    level: 'L4 · Type theory',
    tags: ['FP', 'Category theory'],
    short: 'A structure that wraps values and chains computations that produce them.',
    long: 'A design pattern from category theory that provides a standard way to compose functions that return wrapped values — handling side effects, failure, or asynchrony uniformly.',
    etymology: 'Greek monás (“unit”), via Leibniz’s metaphysics — borrowed by Moggi (1989).',
    example: {
      lang: 'hs',
      code: 'do\n  user <- fetchUser id\n  posts <- fetchPosts user\n  return posts',
    },
    sentence: 'Promises are basically a monad for asynchronous values.',
  },
  {
    id: 'crdt',
    word: 'CRDT',
    pos: 'acronym',
    ipa: 'see-ar-dee-TEE',
    level: 'L4 · Distributed systems',
    tags: ['Sync', 'Offline-first'],
    short: 'Conflict-free Replicated Data Type — merges edits from anywhere, no coordinator needed.',
    long: 'A data structure that can be replicated across many nodes, updated independently and concurrently, and mathematically guaranteed to converge without conflicts.',
    etymology: 'coined by Shapiro et al., 2011 — stands for Conflict-free Replicated Data Type.',
    example: {
      lang: 'ts',
      code: 'const doc = new Y.Doc();\ndoc.getText("title").insert(0, "Hi");\n// merges cleanly with any peer',
    },
    sentence: 'Figma-like multiplayer is often built on CRDTs.',
  },
];

const RECENT_WORDS = [
  { word: 'mutex', date: 'Apr 17', level: 'L2', short: 'A lock that allows only one thread at a time.' },
  { word: 'sidecar', date: 'Apr 16', level: 'L3', short: 'A helper container that runs alongside the main service.' },
  { word: 'thunk', date: 'Apr 15', level: 'L3', short: 'A deferred computation, wrapped as a zero-arg function.' },
  { word: 'eventual consistency', date: 'Apr 14', level: 'L3', short: 'All replicas will agree — given enough time.' },
  { word: 'tombstone', date: 'Apr 13', level: 'L3', short: 'A marker that a record was deleted.' },
  { word: 'hoisting', date: 'Apr 12', level: 'L1', short: 'JS moves declarations to the top of the scope.' },
  { word: 'referential transparency', date: 'Apr 11', level: 'L3', short: 'Same inputs always give the same outputs.' },
  { word: 'gRPC', date: 'Apr 10', level: 'L2', short: 'Binary RPC over HTTP/2, schema-first.' },
];

const SAVED_WORDS = ['backpressure', 'monad', 'sidecar', 'CRDT', 'eventual consistency'];

Object.assign(window, { WORDS_TODAY, RECENT_WORDS, SAVED_WORDS });
