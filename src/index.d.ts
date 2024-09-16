export = Debug;
export as namespace Debug;

/**
 * A standard library for debugging. Contains better {@linkcode error} /
 * {@linkcode warn} functions, an implementation of a table to string
 * converter, and a few more functions.
 *
 * Realistically, you'll only really need a few of these functions ever.
 *
 * - {@linkcode AlphabeticalOrder}
 * - {@linkcode DirectoryToString}
 * - {@linkcode EscapeString}
 * - {@linkcode Inspect}
 * - {@linkcode TableToString}
 *
 * @author Validark
 */
declare namespace Debug {
	/**
	 * Converts an Instance path to a string. Basically a fixed version of
	 * `Instance.GetFullName`.
	 *
	 * @param instance The Instance to convert to a string.
	 * @returns The path of the Instance.
	 */
	export function DirectoryToString(instance: Instance): string;

	/**
	 * The internal formatting mechanism of {@linkcode Assert},
	 * {@linkcode Error}, and {@linkcode Warn}.
	 *
	 * @param formatString The format string.
	 * @param formatArguments The arguments to pass to string.format.
	 * @returns The formatted string.
	 */
	export function InspectFormat(formatString: string, ...formatArguments: ReadonlyArray<unknown>): string;

	/**
	 * Basically returns `condition or Debug.Error(...)`.
	 *
	 * @param condition The condition to assert.
	 * @param formatString The format string.
	 * @param formatArguments The format arguments.
	 */
	export function Assert<T>(
		condition: T,
		formatString: string,
		...formatArguments: ReadonlyArray<unknown>
	): asserts condition;

	/**
	 * A standardized erroring system. Prefixing {@linkcode formatString} with
	 * '!' makes it expect the `[error origin script].Name` as first parameter
	 * in {@linkcode formatArguments}. Past the initial format string,
	 * subsequent arguments get unpacked in a {@linkcode string.format} of the
	 * error string. {@linkcode Assert} falls back on {@linkcode Error}.
	 * {@linkcode Error} blames the latest item on the traceback as the cause
	 * of the error. {@linkcode Error} attempts to make it clear which library
	 * and function are being misused.
	 *
	 * @param formatString The error string.
	 * @param formatArguments What to format the error string with.
	 */
	// biome-ignore lint/suspicious/noShadowRestrictedNames: idiot
	export function Error(formatString: string, ...formatArguments: ReadonlyArray<unknown>): never;

	/**
	 * Functions the same as {@linkcode Error}, but internally calls
	 * {@linkcode warn} instead of {@linkcode error}.
	 *
	 * @param formatString The warning string.
	 * @param formatArguments What to format the warning string with.
	 */
	export function Warn(formatString: string, ...formatArguments: ReadonlyArray<unknown>): void;

	/**
	 * Iteration function that iterates over a dictionary in alphabetical
	 * order. {@linkcode dictionary} is that which will be iterated over in
	 * alphabetical order. Not case-sensitive.
	 *
	 * @example
	 * for (const [key, value] of Debug.AlphabeticalOrder(
	 * 	new Map<string, boolean | number>([
	 * 		["Apple", true],
	 * 		["Noodles", 5],
	 * 		["Soup", false],
	 * 	]),
	 * )) {
	 * 	print(key, value);
	 * }
	 *
	 * @param dictionary The dictionary to iterate over.
	 * @returns The iterator function.
	 */
	export function AlphabeticalOrder<V>(
		dictionary: ReadonlyMap<string, V>,
	): IterableFunction<LuaTuple<[Exclude<string, undefined>, Exclude<V, undefined>]>>;
	export function AlphabeticalOrder<K, V>(
		dictionary: ReadonlyMap<K, V>,
	): IterableFunction<LuaTuple<[Exclude<K, undefined>, Exclude<V, undefined>]>>;
	export function AlphabeticalOrder<V>(
		object: ReadonlyArray<V>,
	): IterableFunction<LuaTuple<[number, Exclude<V, undefined>]>>;
	export function AlphabeticalOrder<V>(
		dictionary: ReadonlySet<V>,
	): IterableFunction<LuaTuple<[Exclude<V, undefined>, true]>>;
	export function AlphabeticalOrder<T extends object>(
		dictionary: T,
	): keyof T extends never
		? IterableFunction<LuaTuple<[unknown, defined]>>
		: IterableFunction<LuaTuple<[keyof T, Exclude<T[keyof T], undefined>]>>;

	/**
	 * Pretty self-explanatory. {@linkcode object} is the table to convert into
	 * a string. {@linkcode tableName} puts `local tableName =` at the
	 * beginning. {@linkcode multiline} makes it multiline.
	 *
	 * Returns a string-readable version of {@linkcode object}.
	 *
	 * @param object The table to convert to a string.
	 * @param multiline Whether or not to make the string multiline.
	 * @param tableName The name of the table.
	 * @returns The string-readable version of {@linkcode object}.
	 */
	export function TableToString<T extends object>(object: T, multiline?: boolean, tableName?: string): string;

	/**
	 * Turns strings into Lua-readable format. Returns Objects location in
	 * proper Lua format. Useful for when you are doing string-intensive
	 * coding. Those minus signs are so tricky!
	 *
	 * @param value The string to escape.
	 * @returns The escaped string.
	 */
	export function EscapeString(value: string): string;

	/**
	 * Returns a string representation of the objects.
	 *
	 * @param inspectArguments The objects to inspect.
	 * @returns The string representation of the objects.
	 */
	export function Inspect(...inspectArguments: ReadonlyArray<unknown>): string;
}
