/*
Copyright © 2022 Chris Berthiaume, University of Washington <chrisbee@uw.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"rockserve/serve"
)

const version = "v0.0.2"

var (
	addr         string
	withProm     bool
	withTestData bool
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "rockserve",
	Short: "A brief description of your application",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Fprintf(os.Stderr, "rockserve version %v\n", version)
		fmt.Fprintf(os.Stderr, "starting server at %v\n", addr)
		if withProm {
			fmt.Fprintf(os.Stderr, "using Prometheus instrumentation\n")
			serve.StartWithPrometheus(addr, withTestData)
		} else {
			serve.Start(addr)
		}
		fmt.Fprintln(os.Stderr, "closing server")
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	cobra.CheckErr(rootCmd.Execute())
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&addr, "address", "a", ":8100", "server bind address")
	rootCmd.PersistentFlags().BoolVarP(&withProm, "prometheus", "p", false, "Instrument with Prometheus")
	rootCmd.PersistentFlags().BoolVarP(&withTestData, "testdata", "t", false, "Output test Prometheus data")
}
