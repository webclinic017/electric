import { makeElectricContext } from 'electric-sql/react'
import { globalRegistry } from 'electric-sql/satellite'
import { ElectricDatabase, electrify } from 'electric-sql/wa-sqlite'
import { ClientTables } from 'electric-sql/client/model'
import { uniqueTabId } from 'electric-sql/util'
import { Electric, schema } from './generated/client/index'
import { unsigned, userId } from './auth'
import { DEBUG_MODE, ELECTRIC_URL } from './config'

export type {
  Electric,
  Demos as Demo,
  Items as Item,
  Players as Player,
  Sliders as Slider,
  Tournaments as Tournament
} from './generated/client/index'

export type DB = Electric['db']

export const { ElectricProvider, useElectric } = makeElectricContext<Electric>()

export const initElectric = async (name: string = 'intro') => {
  const { tabId } = uniqueTabId()
  const tabScopedDbName = `${name}-${tabId}.db`

  const conn = await ElectricDatabase.init(tabScopedDbName, '/')

  const config = {
    auth: {
      token: unsigned(userId())
    },
    url: ELECTRIC_URL,
    debug: DEBUG_MODE
  }

  const electric = await electrify(conn, schema, config)
  const { db } = electric

  await db.raw({sql: 'PRAGMA foreign_keys = 1'})
  await db.raw({
    sql: `UPDATE main._electric_meta set value = ? where key = ?`,
    args: [1, "compensations"],
  });

  return electric
}

// export const cleanupElectric = async (name: string = 'intro') => {
//   await globalRegistry.stop(name)
// }
