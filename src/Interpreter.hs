{-# LANGUAGE OverloadedStrings #-}

module Interpreter
    ( -- * Top-level CLI
      console
    , runCommand
      -- * Interpreter
    , Command(..), Sql(..), Expr(..), interpret
    )
where

import           Control.Monad.State
import qualified Data.ByteString     as BS
import           Data.Monoid         ((<>))
import           Data.Text
import qualified Data.Text.IO        as IO
import           Sql
import           Sql.DB.VectorDB

data Command = Exit
             | SqlStatement Sql
             | Unknown Text
  deriving (Eq, Show)

interpret :: Text -> Command
interpret ".exit" = Exit
interpret s = case parseSQL s of
                Left err  -> Unknown err
                Right sql -> SqlStatement sql

runCommand :: (DB db) => Text -> State db (Maybe Text)
runCommand line = do
  db <- get
  let output = interpret line
  case output of
       SqlStatement sql ->
         let (result, db') = execDatabase db (evaluateDB $ toRelational sql)
         in put db' >> return (Just $pack $ show result)
       Unknown err     -> return $ Just $ "unknown command:" <> err
       Exit            -> return $ Nothing

console' :: (DB db) => db -> IO ()
console' db = do
  putStr "> "
  line <- pack <$> getLine
  let (output,db')  = runState (runCommand line) db
  case output of
    Nothing  -> IO.putStrLn "bye!"
    Just msg -> IO.putStrLn msg >> console' db'

loadDB :: IO BytesDB
loadDB = do
  db <- BS.readFile "./sqlite.db"
  pure BytesDB { bytes = db }

saveDB :: BytesDB -> IO ()
saveDB BytesDB { bytes = db } = do
  BS.writeFile "./sqlite.db" db

console :: IO ()
console = do
    db <- loadDB
    console' db
    saveDB db
