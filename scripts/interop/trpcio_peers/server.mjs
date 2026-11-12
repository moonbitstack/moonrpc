// The TypeScript side of the tRPC-for-TypeScript interop test: the same four procedures
// `src/cmd/trpciod` serves, on the same base path, so one client can be pointed at either.
import { initTRPC, TRPCError } from '@trpc/server'
import { createHTTPServer } from '@trpc/server/adapters/standalone'
import { z } from 'zod'

const port = Number(process.argv[2] ?? 12010)

const t = initTRPC.create()

const router = t.router({
  greet: t.router({
    hello: t.procedure
      .input(z.string().optional())
      .query(({ input }) => ({ greeting: `hello ${input ?? 'world'}` })),
    remember: t.procedure
      .input(z.object({ name: z.string() }))
      .mutation(({ input }) => ({ ok: true, name: input.name })),
    fail: t.procedure.query(() => {
      throw new TRPCError({ code: 'FORBIDDEN', message: 'not for you' })
    }),
  }),
  math: t.router({
    add: t.procedure
      .input(z.object({ a: z.number(), b: z.number() }))
      .query(({ input }) => input.a + input.b),
  }),
})

const server = createHTTPServer({ router, basePath: '/trpc' })
server.listen(port, '127.0.0.1', () => {
  console.log(`trpcio peer listening on 127.0.0.1:${port}`)
})
