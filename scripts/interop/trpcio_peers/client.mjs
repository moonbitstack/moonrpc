// The TypeScript client against the server under test: every call the conformance command
// makes in the other direction, through the real `@trpc/client` links.
import { createTRPCClient, httpBatchLink, httpLink } from '@trpc/client'

const url = process.argv[2] ?? 'http://127.0.0.1:12000/trpc'

let failures = 0
const check = (what, actual, expected) => {
  const a = JSON.stringify(actual)
  const e = JSON.stringify(expected)
  if (a !== e) {
    console.error(`check: ${what}: ${a} != ${e}`)
    failures += 1
  }
}

const http = createTRPCClient({ links: [httpLink({ url })] })

const greeting = await http.greet.hello.query('moon')
check('greet.hello', greeting, { greeting: 'hello moon' })

const bare = await http.greet.hello.query()
check('greet.hello without input', bare, { greeting: 'hello world' })

const sum = await http.math.add.query({ a: 2, b: 40 })
check('math.add', sum, 42)

const remembered = await http.greet.remember.mutate({ name: 'moon' })
check('greet.remember', remembered, { ok: true, name: 'moon' })

try {
  await http.greet.fail.query()
  console.error('check: greet.fail answered instead of failing')
  failures += 1
} catch (error) {
  const code = error?.data?.code ?? error?.shape?.data?.code
  const status = error?.data?.httpStatus ?? error?.shape?.data?.httpStatus
  check('greet.fail code', code, 'FORBIDDEN')
  check('greet.fail status', status, 403)
}

// One request, three answers, in the order they were asked for.
const batched = createTRPCClient({ links: [httpBatchLink({ url })] })
const answers = await Promise.allSettled([
  batched.greet.hello.query('batch'),
  batched.math.add.query({ a: 1, b: 2 }),
  batched.greet.fail.query(),
])
check('batch answer 0', answers[0], { status: 'fulfilled', value: { greeting: 'hello batch' } })
check('batch answer 1', answers[1], { status: 'fulfilled', value: 3 })
check('batch answer 2', answers[2].status, 'rejected')

if (failures === 0) {
  console.log('trpcio client: ok')
} else {
  console.error(`trpcio client: ${failures} failed`)
  process.exit(1)
}
